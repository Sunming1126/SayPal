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

  Future<Uri?> resolveOrigin({required bool original}) async {
    if (_mediaBaseUrl != _defaultMediaBase) return null;
    final lessonNumber = RegExp(r'^lesson-(\d{3})$').firstMatch(id)?.group(1);
    final endpoint = switch (id) {
      'clever-rat' || 'teachers-office' => id,
      _ when lessonNumber != null => 'main/${int.parse(lessonNumber)}',
      _ => null,
    };
    if (endpoint == null) return null;
    try {
      final response = await http
          .get(_mediaBase.resolve('/saypal/video-origin/$endpoint'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final video = decoded['topic']['video'] as Map<String, dynamic>;
      if (!original) return _readOriginUrl(video['url']);
      final streams = video['streams'] as List<dynamic>?;
      for (final stream in streams ?? const []) {
        if (stream is Map && stream['definition'] == 'OD') {
          return _readOriginUrl(stream['url']);
        }
      }
    } on Exception {
      return null;
    } on TypeError {
      return null;
    }
    return null;
  }

  static Uri? _readOriginUrl(Object? url) {
    if (url is! String) return null;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.host != 'yx.zqyey.com.cn' &&
            !uri.host.endsWith('.aliyuncs.com'))) {
      return null;
    }
    final expires = int.tryParse(uri.queryParameters['Expires'] ?? '');
    if (expires != null &&
        expires <= DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30) {
      return null;
    }
    return uri;
  }

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
