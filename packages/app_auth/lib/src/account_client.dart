import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_models.dart';

/// Deletes the server-side account. The backend removes the Firebase user
/// record (via the Admin SDK) and all Prisma rows for the UID, so the client
/// only needs to clear its local session afterwards.
abstract interface class AccountClient {
  Future<void> deleteAccount(String idToken);
}

class HttpAccountClient implements AccountClient {
  HttpAccountClient({
    required this.apiBaseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<void> deleteAccount(String idToken) async {
    final response = await _client
        .delete(_endpoint('account'), headers: _headers(idToken))
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _failure(response);
    }
  }

  Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Uri _endpoint(String relativePath) {
    final basePath = apiBaseUri.path.endsWith('/')
        ? apiBaseUri.path
        : '${apiBaseUri.path}/';
    return apiBaseUri.replace(path: '$basePath$relativePath');
  }

  AuthFailure _failure(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map<String, dynamic>) {
        final code = value['code'] as String?;
        final message = value['message'] as String?;
        if (code != null && code.isNotEmpty) {
          return AuthFailure(code, message);
        }
      }
    } on FormatException {
      // Non-JSON error body; fall through to a generic failure.
    }
    if (response.statusCode >= 500) {
      return const AuthFailure('network-request-failed');
    }
    return AuthFailure(
      'account-deletion-failed',
      response.statusCode.toString(),
    );
  }
}
