import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:saypal/features/realtime/voice/buffered_pcm_recorder.dart';
import 'package:saypal/features/realtime/voice/conversation_context.dart';
import 'package:saypal/features/realtime/voice/voice_conversation_controller.dart';
import 'package:saypal/features/realtime/voice/voice_transport.dart';
import 'package:saypal/features/realtime/voice/websocket_voice_transport.dart';

void main() {
  test('WebSocket connect waits for the application ready message', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final peer = Completer<WebSocket>();
    server.listen((request) async {
      peer.complete(await WebSocketTransformer.upgrade(request));
    });
    final transport = WebsocketVoiceTransport('http://127.0.0.1:${server.port}');
    addTearDown(transport.close);
    final readyEvent = transport.events.first;
    var connected = false;
    final opening = transport
        .connect(context: const ConversationContext.freeChat())
        .then((_) => connected = true);
    final socket = await peer.future;
    addTearDown(socket.close);
    // An unrelated event establishes that the upgrade and listener are live.
    await socket.addStream(Stream.value('{"type":"connection_stage"}'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(connected, isFalse);
    socket.add('{"type":"ready"}');
    expect((await readyEvent)['type'], 'ready');
    expect(await opening, isTrue);
  });

  test('WebSocket 403 is a credential error and is not retried', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
    });
    final transport = WebsocketVoiceTransport('http://127.0.0.1:${server.port}');
    addTearDown(transport.close);
    await expectLater(
      transport.connect(context: const ConversationContext.freeChat()),
      throwsA(isA<VoiceFailure>()
          .having((e) => e.message, 'message', contains('凭证'))
          .having((e) => e.retryable, 'retryable', isFalse)),
    );
  });

  test(
    'WebSocket streams PCM before release and sends one end marker',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final commands = StreamController<dynamic>();
      final received = StreamIterator(commands.stream);
      addTearDown(received.cancel);
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        socket.add('{"type":"ready"}');
        socket.listen(commands.add, onDone: commands.close);
      });
      final transport = WebsocketVoiceTransport(
        'http://127.0.0.1:${server.port}',
      );
      addTearDown(transport.close);
      await transport.connect(context: const ConversationContext.freeChat());

      final frames = StreamController<Uint8List>();
      final upload = transport.uploadBufferedAudio(frames.stream);
      frames.add(Uint8List.fromList([1, 2]));
      expect(await received.moveNext(), isTrue);
      expect(received.current, '{"type":"start"}');
      expect(await received.moveNext(), isTrue);
      expect(received.current, [1, 2]);

      frames.add(Uint8List.fromList([3, 4]));
      await frames.close();
      await upload;
      await transport.commitBufferedAudio();
      expect(await received.moveNext(), isTrue);
      expect(received.current, [3, 4]);
      expect(await received.moveNext(), isTrue);
      expect(received.current, '{"type":"end"}');
    },
  );

  test('release shows a draft immediately during recorder startup', () async {
    final transport = _FakeVoiceTransport();
    final recorder = _FakeRecorder();
    final controller = VoiceConversationController(
      () => transport,
      recorderFactory: () => recorder,
    );
    late VoiceChatState state;
    controller.addListener((current) => state = current);
    addTearDown(controller.dispose);

    final start = controller.startRecording();
    final submit = controller.endRecording();
    final displayId = state.displayMessages.single.displayId;
    expect(state.displayMessages.single.isProvisional, isTrue);
    expect(state.messages, isEmpty);
    expect(transport.commits, 0);
    recorder.started.complete();
    await start;
    await submit;
    expect(transport.commits, 1);

    transport.emit({'type': 'partial', 'text': 'I like'});
    expect(state.displayMessages.single.text, 'I like');
    transport.emit({'type': 'transcript', 'id': '1', 'text': 'I like apples.'});
    expect(state.displayMessages.single.text, 'I like apples.');
    expect(state.displayMessages.single.isProvisional, isFalse);
    expect(state.messages.single.id, '1');
    expect(state.displayMessages.single.displayId, displayId);
  });

  test('cancelling during recorder startup discards a released turn', () async {
    final transport = _FakeVoiceTransport();
    final recorder = _FakeRecorder();
    final controller = VoiceConversationController(
      () => transport,
      recorderFactory: () => recorder,
    );
    late VoiceChatState state;
    controller.addListener((current) => state = current);
    addTearDown(controller.dispose);

    final start = controller.startRecording();
    final submit = controller.endRecording();
    final cancel = controller.cancelPendingTurn();
    recorder.started.complete();
    await Future.wait([start, submit, cancel]);

    expect(transport.commits, 0);
    expect(state.displayMessages, isEmpty);
    expect(state.canStartTurn, isTrue);
  });

  test(
    'partial replies keep the turn busy and missing audio permits next turn',
    () async {
      final transport = _FakeVoiceTransport();
      final controller = VoiceConversationController(() => transport);
      late VoiceChatState state;
      controller.addListener((current) => state = current);
      addTearDown(controller.dispose);

    await controller.sendText('apple');
    transport.emit({'type': 'reply_segment', 'id': '1', 'text': 'I like apples.'});
    expect(state.messages.last.text, 'I like apples.');
    expect(state.canStartTurn, isFalse);
    await controller.sendText('too early');
    expect(transport.sent, ['apple']);

    transport.emit({'type': 'error', 'message': '有一句语音播放生成失败，文字仍可阅读。'});
    expect(state.notice, contains('可以继续对话'));
    expect(state.error, isEmpty);
    expect(state.canStartTurn, isFalse);
    transport.emit({'type': 'done'});
    expect(state.canStartTurn, isTrue);
    await controller.sendText('pear');
    expect(transport.sent, ['apple', 'pear']);
  });
}

class _FakeVoiceTransport implements VoiceTransport {
  final _events = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  final sent = <String>[];
  int commits = 0;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Future<void> connect({required ConversationContext context}) async {
    emit({'type': 'ready'});
  }

  @override
  Future<void> send(Map<String, dynamic> command) async {
    sent.add(command['text'] as String);
  }

  @override
  Future<void> setSessionActive(bool active) async {}

  @override
  Future<void> uploadBufferedAudio(Stream<Uint8List> pcm) => pcm.drain();

  @override
  Future<void> commitBufferedAudio() async {
    commits++;
  }

  @override
  Future<void> cancelPendingTurn() async {}

  @override
  Future<void> close() => _events.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRecorder implements PcmRecorder {
  final started = Completer<void>();
  final _frames = StreamController<Uint8List>();

  @override
  Stream<Uint8List> get frames => _frames.stream;

  @override
  Future<void> start({required void Function() onLimit}) => started.future;

  @override
  Future<void> stop() => _frames.close();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}
