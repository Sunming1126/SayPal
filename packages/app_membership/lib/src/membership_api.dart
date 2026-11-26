import 'dart:convert';

import 'package:http/http.dart' as http;

import 'membership_models.dart';

abstract interface class MembershipApi {
  Future<MembershipSnapshot> fetchMembership(String idToken);

  Future<MembershipSnapshot> verifyAppleTransaction({
    required String idToken,
    required String productId,
    required String verificationData,
    String? transactionDate,
  });
}

class HttpMembershipApi implements MembershipApi {
  HttpMembershipApi({
    required this.apiBaseUri,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final Uri apiBaseUri;
  final Duration timeout;
  final http.Client _client;

  @override
  Future<MembershipSnapshot> fetchMembership(String idToken) async {
    final response = await _client
        .get(_endpoint('membership'), headers: _headers(idToken))
        .timeout(timeout);
    return _snapshot(response);
  }

  @override
  Future<MembershipSnapshot> verifyAppleTransaction({
    required String idToken,
    required String productId,
    required String verificationData,
    String? transactionDate,
  }) async {
    final response = await _client
        .post(
          _endpoint('membership/apple/transactions/verify'),
          headers: _headers(idToken),
          body: jsonEncode({
            'productId': productId,
            'verificationData': verificationData,
            'transactionDate': ?transactionDate,
          }),
        )
        .timeout(timeout);
    return _snapshot(response);
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

  MembershipSnapshot _snapshot(http.Response response) {
    final body = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MembershipFailure(
        body['code'] as String? ?? 'membership_request_failed',
        body['message'] as String?,
      );
    }
    return MembershipSnapshot.fromJson(body);
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      return value is Map<String, dynamic> ? value : const {};
    } on FormatException {
      return const {};
    }
  }
}
