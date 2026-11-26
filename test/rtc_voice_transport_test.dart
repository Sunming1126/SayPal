import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saypal/features/realtime/voice/conversation_context.dart';
import 'package:saypal/features/realtime/voice/rtc_voice_transport.dart';

void main() {
  test(
    'RTC streams subtitles before submit and completes on the last AI subtitle',
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
      bridge.subtitle('teacher', 'Do you live nearby?', 3, true);
      await Future<void>.delayed(Duration.zero);
      expect(
        events.where((e) => e['type'] == 'reply_segment').map((e) => e['text']),
        ['Nice to meet you.', 'Do you live nearby?'],
      );
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
      await transport.close();
      expect(requests.last, endsWith('/rtc/session/session/stop'));
    },
  );
}

class _Bridge implements RtcAudioBridge {
  final output = StreamController<Map<String, dynamic>>.broadcast();
  final firstFrame = Completer<void>();
  final controls = <Map>[];
  bool joined = false;

  @override
  Stream<Map<String, dynamic>> get events => output.stream;

  void subtitle(String user, String text, int sequence, bool paragraph) {
    output.add({
      'type': 'subtitle',
      'userId': user,
      'text': text,
      'roundId': 1,
      'sequence': sequence,
      'definite': true,
      'paragraph': paragraph,
    });
  }

  @override
  Future<void> join(RtcSessionCredentials credentials) async => joined = true;
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
