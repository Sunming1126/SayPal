import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../realtime/voice/conversation_context.dart';

final _mediaBase = Uri.parse(
  const String.fromEnvironment(
    'SAYPAL_VIDEO_PRACTICE_URL',
    defaultValue: 'https://onesay.top/saypal/video-practice/v1/',
  ),
);

final videoRoleplayLessonsProvider = FutureProvider<List<VideoRoleplayLesson>>((
  ref,
) async {
  final client = http.Client();
  ref.onDispose(client.close);
  final response = await client
      .get(_mediaBase.resolve('catalog.json'))
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) {
    throw StateError('Video lesson catalog unavailable');
  }
  final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  final lessons = rows
      .map((row) {
        return VideoRoleplayLesson.fromJson(row as Map<String, dynamic>);
      })
      .toList(growable: false);
  if (lessons.isEmpty ||
      lessons.map((lesson) => lesson.id).toSet().length != lessons.length) {
    throw const FormatException('Invalid video lesson catalog');
  }
  return lessons;
});

class VideoRoleplayLesson {
  const VideoRoleplayLesson({
    required this.id,
    required this.title,
    required this.englishTitle,
    required this.learnerRole,
    required this.aiRole,
    required this.situation,
    required this.opening,
    required this.objectives,
  });

  factory VideoRoleplayLesson.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final objectives = List<String>.unmodifiable(json['objectives'] as List);
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(id) ||
        objectives.length != 3) {
      throw const FormatException('Invalid video lesson');
    }
    return VideoRoleplayLesson(
      id: id,
      title: json['title'] as String,
      englishTitle: json['englishTitle'] as String,
      learnerRole: json['learnerRole'] as String,
      aiRole: json['aiRole'] as String,
      situation: json['situation'] as String,
      opening: json['opening'] as String,
      objectives: objectives,
    );
  }

  final String id;
  final String title;
  final String englishTitle;
  final String learnerRole;
  final String aiRole;
  final String situation;
  final String opening;
  final List<String> objectives;

  Uri get videoUri => _mediaBase.resolve('$id.mp4');
  String get catalogId => 'video-$id';
  String get route => '/scenario/video-practice/$id';

  static String? routeFromCatalogId(String? catalogId) =>
      catalogId != null && catalogId.startsWith('video-')
      ? '/scenario/video-practice/${catalogId.substring('video-'.length)}'
      : null;

  ConversationContext toContext() => ConversationContext(
    kind: ConversationKind.roleplay,
    catalogId: catalogId,
    title: title,
    learnerRole: learnerRole,
    aiRole: aiRole,
    situation: situation,
    objectives: objectives,
  );
}
