import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:saypal/features/scenario/data/video_roleplay_lessons.dart';

void main() {
  const lesson = VideoRoleplayLesson(
    id: 'lesson-001',
    title: 'My Family',
    englishTitle: 'My Family',
    learnerRole: 'Learner',
    aiRole: 'Teacher',
    situation: 'Talk about the family in the lesson.',
    opening: 'Who is in the video?',
    objectives: ['Describe the family.'],
    hasOriginal: true,
  );

  test('selects the legacy default or original rendition', () async {
    const standard = 'https://media.oss-cn-shanghai.aliyuncs.com/default.mp4';
    const original = 'https://media.oss-cn-shanghai.aliyuncs.com/original.mp4';
    final client = MockClient((request) async {
      expect(request.url.path, '/saypal/video-origin/main/1');
      return http.Response(
        jsonEncode({
          'topic': {
            'video': {
              'url': standard,
              'streams': [
                {'definition': 'OD', 'url': original},
                {'definition': 'LD', 'url': standard},
              ],
            },
          },
        }),
        200,
      );
    });

    final results = await http.runWithClient(
      () async => [
        await lesson.resolveOrigin(original: false),
        await lesson.resolveOrigin(original: true),
      ],
      () => client,
    );
    expect(results, [Uri.parse(standard), Uri.parse(original)]);
  });

  test('uses the hosted fallback when the legacy link is expired', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'topic': {
            'video': {
              'url':
                  'https://media.oss-cn-shanghai.aliyuncs.com/v.mp4?Expires=1',
            },
          },
        }),
        200,
      ),
    );

    final result = await http.runWithClient(
      () => lesson.resolveOrigin(original: false),
      () => client,
    );
    expect(result, isNull);
    expect(lesson.videoUri.host, 'onesay.top');
  });
}
