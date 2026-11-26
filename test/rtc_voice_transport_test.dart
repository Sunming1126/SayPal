import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saypal/features/realtime/voice/conversation_context.dart';
import 'package:saypal/features/realtime/voice/rtc_voice_transport.dart';

void main() {
  test('decodes only RTC answerFinish with a valid round and envelope', () {
    Uint8List event(int code) {
      final json = utf8.encode(jsonEncode({
        'Stage': {'Code': code},
        'RoundID': 7,
      }));
      final length = ByteData(4)..setUint32(0, json.length);
      return Uint8List.fromList([
        ...ascii.encode('conv'), ...length.buffer.asUint8List(), ...json,
      ]);
    }

    expect(decodeRtcAnswerFinish(event(5)), 7);
    expect(decodeRtcAnswerFinish(event(4)), isNull);
    expect(decodeRtcAnswerFinish(event(5).sublist(0, 12)), isNull);
  });

  test(
    'RTC consumes a prefetched token once and starts while joining',
    () async {
      final joinGate = Completer<void>();
      final starting = Completer<void>();
      final bridge = _Bridge(joinGate: joinGate.future);
      var bootstraps = 0;
      final api = RtcVoiceSessionApi(
        'https://example.test',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/bootstrap')) {
            return http.Response(
              jsonEncode({
                'sessionId': 'session-${++bootstraps}',
                'appId': 'app',
                'roomId': 'room',
                'userId': 'learner',
                'botUserId': 'teacher',
                'token': 'room-token',
                'expiresAt':
                    DateTime.now().millisecondsSinceEpoch ~/ 1000 + 900,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/start')) {
            expect(request.url.path, contains('/session-1/'));
            expect(bridge.joined, isFalse);
            bridge.output.add({'type': 'bot_ready'});
            starting.complete();
          }
          return http.Response('{}', 200);
        }),
      );
      addTearDown(api.close);
      final transport = RtcVoiceTransport(
        'https://example.test',
        bridge: bridge,
        sessionApi: api,
        parallelStartup: true,
      );
      api.prefetchFreeChat();
      api.prefetchFreeChat();
      final opening = transport.connect(
        context: const ConversationContext.freeChat(),
      );
      await starting.future.timeout(const Duration(seconds: 2));
      joinGate.complete();
      await opening;
      expect(bootstraps, 1);
      await transport.close();

      final next = await api.take(const ConversationContext.freeChat());
      expect(next.sessionId, 'session-2');
    },
  );

  test(
    'RTC streams subtitles and completes on answerFinish or subtitle inactivity',
    () async {
      final bridge = _Bridge();
      final requests = <String>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        requests.add(path);
        if (path.endsWith('/bootstrap')) {
          final context = (jsonDecode(request.body) as Map)['context'] as Map;
          expect(context['kind'], 'customRoleplay');
          expect(context['catalogId'], 'neighbor-chat');
          return http.Response(
            jsonEncode({
              'sessionId': 'session',
              'appId': 'app',
              'roomId': 'room',
              'userId': 'learner',
              'botUserId': 'teacher',
              'token': 'room-token',
            }),
            200,
          );
        }
        if (path.endsWith('/start')) {
          expect(bridge.joined, isTrue);
          bridge.output.add({'type': 'bot_ready'});
        }
        if (path.endsWith('/translate')) {
          return http.Response(
            '{"translation":"译文"}',
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });
      final transport = RtcVoiceTransport(
        'https://example.test/saypal/voice',
        bridge: bridge,
        client: client,
        replyIdleTimeout: const Duration(milliseconds: 150),
      );
      final events = <Map<String, dynamic>>[];
      final subscription = transport.events.listen(events.add);
      addTearDown(() async {
        await subscription.cancel();
        await transport.close();
      });
      await transport.connect(
        context: const ConversationContext(
          kind: ConversationKind.roleplay,
          catalogId: 'neighbor-chat',
          title: 'Meet a neighbor',
          learnerRole: 'Neighbor',
          aiRole: 'Neighbor',
          situation: 'At home',
          objectives: ['Say hello', 'Introduce yourself', 'Say goodbye'],
        ),
      );
      final frames = StreamController<Uint8List>();
      final upload = transport.uploadBufferedAudio(frames.stream);
      frames.add(Uint8List(320));
      await bridge.firstFrame.future;
      bridge.subtitle('learner', 'Hello there!', 1, true);
      bridge.subtitle('teacher', 'Premature reply.', 1, true);
      await Future<void>.delayed(Duration.zero);
      expect(events.last['type'], 'partial');
      expect(events.last['text'], 'Hello there!');
      expect(bridge.controls, isEmpty);
      await frames.close();
      await upload;
      await transport.commitBufferedAudio();
      expect(bridge.controls.single['Command'], 'ExternalTextToLLM');
      expect(bridge.controls.single['Message'], 'Hello there!');

      bridge.subtitle('teacher', 'Nice to meet you.', 2, false);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e['type'] == 'done'), isEmpty);
      bridge.subtitle('teacher', 'Do you live nearby?', 3, false);
      await Future<void>.delayed(Duration.zero);
      expect(
        events.where((e) => e['type'] == 'reply_segment').map((e) => e['text']),
        ['Nice to meet you.', 'Do you live nearby?'],
      );
      expect(events.where((e) => e['type'] == 'done'), isEmpty);
      bridge.finishRound(1);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e['type'] == 'done'), hasLength(1));
      expect(
        events.singleWhere(
          (e) => e['type'] == 'practice_progress',
        )['completed'],
        1,
      );
      expect(
        events.where((e) => e['type'] == 'reply_translation'),
        hasLength(2),
      );

      await transport.send({'type': 'text', 'text': 'Yes, I do.'});
      bridge.finishRound(1);
      bridge.subtitle('teacher', 'Nice neighborhood!', 1, false, round: 2);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e['type'] == 'done'), hasLength(1));
      final fallback = transport.events.firstWhere((e) => e['type'] == 'done');
      await fallback.timeout(const Duration(seconds: 2));
      bridge.finishRound(2);
      await Future<void>.delayed(Duration.zero);
      expect(events.where((e) => e['type'] == 'done'), hasLength(2));
      await transport.close();
      expect(requests.last, endsWith('/rtc/session/session/stop'));
    },
  );
}

class _Bridge implements RtcAudioBridge {
  _Bridge({this.joinGate});

  final Future<void>? joinGate;
  final output = StreamController<Map<String, dynamic>>.broadcast();
  final firstFrame = Completer<void>();
  final controls = <Map>[];
  bool joined = false;

  @override
  Stream<Map<String, dynamic>> get events => output.stream;

  void subtitle(String user, String text, int sequence, bool paragraph, {int round = 1}) {
    output.add({
      'type': 'subtitle',
      'userId': user,
      'text': text,
      'roundId': round,
      'sequence': sequence,
      'definite': true,
      'paragraph': paragraph,
    });
  }

  void finishRound(int round) => output.add({'type': 'answer_finish', 'roundId': round});

  @override
  Future<void> join(RtcSessionCredentials credentials) async {
    await joinGate;
    joined = true;
  }

  @override
  Future<void> setRemoteMuted(bool muted) async {}
  @override
  Future<void> setPublishing(bool publishing) async {}
  @override
  Future<void> startExternalPublishing() async {}
  @override
  Future<void> stopExternalPublishing() async {}
  @override
  Future<void> pushPcmFrame(Uint8List pcm) async => firstFrame.complete();
  @override
  Future<void> sendControl({
    required String userId,
    required Uint8List data,
  }) async {
    controls.add(jsonDecode(utf8.decode(data.sublist(8))) as Map);
  }

  @override
  Future<void> close() => output.close();
}
