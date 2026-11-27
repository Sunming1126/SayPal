import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../realtime/voice/conversation_context.dart';

const _defaultMediaBase = 'https://onesay.top/saypal/video-practice/v3/';
const _mediaBaseUrl = String.fromEnvironment(
  'SAYPAL_VIDEO_PRACTICE_URL',
  defaultValue: _defaultMediaBase,
);
final _mediaBase = Uri.parse(_mediaBaseUrl);

final _onlineCatalogProvider = FutureProvider<List<VideoRoleplayLesson>>((
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
  return _decodeCatalog(utf8.decode(response.bodyBytes));
});

final _bundledCatalogProvider = FutureProvider<List<VideoRoleplayLesson>>((
  ref,
) async {
  final json = await rootBundle.loadString(
    'assets/content/video_roleplay_catalog.json',
  );
  return _decodeCatalog(json);
});

final videoRoleplayLessonsProvider =
    Provider<AsyncValue<List<VideoRoleplayLesson>>>((ref) {
      final online = ref.watch(_onlineCatalogProvider);
      if (_mediaBaseUrl != _defaultMediaBase || online.hasValue) return online;
      final bundled = ref.watch(_bundledCatalogProvider);
      return bundled.hasValue || bundled.isLoading ? bundled : online;
    });

void reloadVideoRoleplayLessons(WidgetRef ref) {
  ref.invalidate(_onlineCatalogProvider);
  ref.invalidate(_bundledCatalogProvider);
}

List<VideoRoleplayLesson> _decodeCatalog(String json) {
  final rows = jsonDecode(json) as List<dynamic>;
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
}

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
    this.hasOriginal = false,
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
      hasOriginal: json['hasOriginal'] == true,
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
  final bool hasOriginal;

  Uri get videoUri => _mediaBase.resolve('$id.mp4');
  Uri get coverUri => _mediaBase.resolve('covers/$id.jpg');
  Uri? get originalVideoUri =>
      hasOriginal ? _mediaBase.resolve('original/$id.mp4') : null;
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
