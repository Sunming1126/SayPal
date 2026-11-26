import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../../core/config/service_endpoint.dart';
import '../../realtime/voice/conversation_context.dart';
import '../../realtime/voice/voice_conversation_controller.dart';

class RoleplaySuggestion {
  const RoleplaySuggestion({
    required this.text,
    required this.translation,
    this.audio,
  });

  final String text;
  final String translation;
  final Uint8List? audio;
}

abstract interface class RoleplaySuggestionRepository {
  Future<RoleplaySuggestion> generate({
    required ConversationContext context,
    required List<VoiceMessage> messages,
  });
}

class HttpRoleplaySuggestionRepository
    implements RoleplaySuggestionRepository {
  HttpRoleplaySuggestionRepository({String? baseUrl})
      : _baseUrl =
            baseUrl ?? const String.fromEnvironment('SAYPAL_API_BASE_URL');

  final String _baseUrl;

  String get _resolvedBaseUrl => _baseUrl.isNotEmpty
      ? _baseUrl
      : (kDebugMode ? 'http://localhost:8000' : '');

  @override
  Future<RoleplaySuggestion> generate({
    required ConversationContext context,
    required List<VoiceMessage> messages,
  }) async {
    final Uri? uri =
        resolveServiceEndpoint(_resolvedBaseUrl, 'roleplay/suggestion');
    if (uri == null || !uri.hasScheme) {
      throw const HttpException('suggestion_not_configured');
    }
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.postUrl(uri).timeout(const Duration(seconds: 10));
      request.headers.contentType = ContentType.json;
      const String token = String.fromEnvironment('SAYPAL_CHAT_TOKEN');
      if (token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final List<VoiceMessage> recent =
          messages.length <= 8 ? messages : messages.sublist(messages.length - 8);
      request.write(jsonEncode(<String, dynamic>{
        'context': context.toJson(),
        'messages': recent
            .map((VoiceMessage message) => <String, String>{
                  'role': message.child ? 'learner' : 'assistant',
                  'text': message.text,
                })
            .toList(growable: false),
      }));
      final HttpClientResponse response =
          await request.close().timeout(const Duration(seconds: 25));
      final String body = await utf8.decodeStream(response);
      if (response.statusCode != 200) {
        throw const HttpException('suggestion_failed');
      }
      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      final String text = (json['text'] as String? ?? '').trim();
      final String translation =
          (json['translation'] as String? ?? '').trim();
      if (text.isEmpty || translation.isEmpty) {
        throw const FormatException('invalid_suggestion');
      }
      final String audio = json['audio'] as String? ?? '';
      return RoleplaySuggestion(
        text: text,
        translation: translation,
        audio: audio.isEmpty ? null : base64Decode(audio),
      );
    } finally {
      client.close(force: true);
    }
  }
}
