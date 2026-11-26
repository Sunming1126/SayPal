import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

abstract interface class EmailOtpClient {
  Future<EmailCodeChallenge> requestCode(String email);

  Future<String> verifyCode({
    required String email,
    required String challengeId,
    required String code,
  });
}

class HttpEmailOtpClient implements EmailOtpClient {
  HttpEmailOtpClient({
    required this.apiBaseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<EmailCodeChallenge> requestCode(String email) async {
    final response = await _client
        .post(
          _endpoint('auth/email-code/request'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(timeout);
    final body = _decode(response);
    if (response.statusCode != 202) throw _failure(response, body);
    return EmailCodeChallenge(
      challengeId: body['challengeId'] as String,
      expiresInSeconds: (body['expiresInSeconds'] as num).toInt(),
      resendAfterSeconds: (body['resendAfterSeconds'] as num).toInt(),
    );
  }

  @override
  Future<String> verifyCode({
    required String email,
    required String challengeId,
    required String code,
  }) async {
    final response = await _client
        .post(
          _endpoint('auth/email-code/verify'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim(),
            'challengeId': challengeId,
            'code': code.trim(),
          }),
        )
        .timeout(timeout);
    final body = _decode(response);
    if (response.statusCode != 200) throw _failure(response, body);
    final token = body['firebaseCustomToken'] as String?;
    if (token == null || token.isEmpty) {
      throw const AuthFailure('email-code-token-missing');
    }
    return token;
  }

  Uri _endpoint(String relativePath) {
    final basePath = apiBaseUri.path.endsWith('/')
        ? apiBaseUri.path
        : '${apiBaseUri.path}/';
    return apiBaseUri.replace(path: '$basePath$relativePath');
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }

  AuthFailure _failure(http.Response response, Map<String, dynamic> body) {
    final code = body['code'] as String?;
    final message = body['message'] as String?;
    if (code != null && code.isNotEmpty) return AuthFailure(code, message);
    if (response.statusCode >= 500) {
      return const AuthFailure('network-request-failed');
    }
    return AuthFailure('email-code-request-failed', message);
  }
}
