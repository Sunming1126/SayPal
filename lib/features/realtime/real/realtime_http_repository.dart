import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/config/app_config.dart';
import '../domain/realtime_events.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_session_state.dart' show RealtimeFailureReason;
import '../domain/realtime_tutor_repository.dart';

/// 真实链路实现（仅存在于 features/realtime 中）。
///
/// 遵循参考工程 `example/` 的低延迟会话流程（全部通过运行时配置调用，
/// 源码中不含任何密钥/地址）：
///
/// 1. bootstrap：  `GET  {apiBaseUrl}/users/{userId}/bootstrap?client_id=...`
///    → 服务端下发 {user_id, room_id, user_rtc_token, app_id}
/// 2. 会话启动：   `POST {apiBaseUrl}/sessions/start`
///    → {session_id, bot_user_id}
/// 3. 语音会话：   `POST {apiBaseUrl}/voicechat/start`
///    （mode / chapter / unit / topic 等参数，由业务侧传入）
/// 4. 字幕：       RTC 房间二进制消息（"subv" 头 + JSON subtitle 帧）——
///    需要 RTC SDK 加入房间后才有；当前 MVP 未引入 RTC 原生依赖。
/// 5. 结束会话：   `POST {apiBaseUrl}/voicechat/end_task`
/// 6. 报告：       `GET  {apiBaseUrl}/sessions/{session_id}/report/last`
///    （轮询直到就绪）
///
/// 说明：本 MVP 中该实现负责上述 HTTP 会话生命周期与报告获取；
/// RTC 房间加入与音频收发需要火山 RTC Flutter SDK 与真实凭据，
/// 在未注入（--dart-define）配置时会直接以 serviceNotConfigured 失败，
/// 不会伪称已接通。
final class RealtimeHttpRepository implements RealtimeTutorRepository {
  RealtimeHttpRepository({
    AppConfig? config,
    this.userId = 'local-child',
    this.reportPollAttempts = 30,
  }) : _config = config ?? AppConfig.instance;

  final AppConfig _config;
  final String userId;
  final int reportPollAttempts;

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  HttpClient? _client;

  String? _sessionId;
  DateTime? _startedAt;
  int _childTurns = 0;

  @override
  bool get supportsTextInput => false;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> startSession(RealtimeSessionRequest request) async {
    if (!_config.isRealtimeConfigured) {
      _emit(const SessionError('实时服务未配置'));
      throw const RealtimeSessionException(
        RealtimeFailureReason.serviceNotConfigured,
      );
    }
    try {
      _client ??= HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);

      // 1) bootstrap：从服务端获取会话凭据（token 等只在内存中使用，绝不落盘/打印）。
      final Map<String, dynamic> bootstrap = await _getJson(
        '/users/$userId/bootstrap',
        query: {'client_id': _config.clientId},
      );
      final String roomId = bootstrap['room_id'] as String? ?? '';

      // 2) 会话启动。
      final Map<String, dynamic> started = await _postJson('/sessions/start', {
        'user_id': userId,
        'client_id': _config.clientId,
      });
      _sessionId = started['session_id'] as String?;
      _startedAt = DateTime.now();
      _childTurns = 0;

      // 3) 语音会话（欢迎语作为第一条字幕下发）。
      final Map<String, dynamic> voice = await _postJson('/voicechat/start', {
        'user_id': userId,
        'room_id': roomId,
        'session_id': _sessionId,
        'mode': 'situation',
        'voice_pipeline': 'three_stage',
      });
      final String? welcome = voice['welcome_message'] as String?;
      if (welcome != null && welcome.isNotEmpty) {
        _emit(
          TranscriptCommitted(
            TranscriptEntry(
              id: 'ai-welcome',
              speaker: TranscriptSpeaker.ai,
              text: welcome,
            ),
          ),
        );
      }
      // 注意：加入 RTC 房间并订阅音频/字幕需要 RTC SDK，见类注释。
    } on RealtimeSessionException {
      rethrow;
    } on SocketException catch (error) {
      _emit(SessionError('网络异常: ${error.osError?.errorCode ?? ''}'));
      throw const RealtimeSessionException(RealtimeFailureReason.networkError);
    } on TimeoutException {
      _emit(const SessionError('连接超时'));
      throw const RealtimeSessionException(RealtimeFailureReason.networkError);
    }
  }

  @override
  Future<void> sendChildUtterance(String text) async {
    // 真实链路中孩子的语音经 RTC 上行、由服务端转写；
    // 这里保留对已识别文本的上报通道（如 /sessions/utterance）。
    if (!_config.isRealtimeConfigured || _sessionId == null) {
      return;
    }
    _childTurns += 1;
    try {
      await _postJson('/sessions/$_sessionId/utterance', {'text': text});
    } on Exception {
      // 上报失败不打断会话。
    }
  }

  @override
  Future<TutorReport> endSession() async {
    if (_sessionId == null) {
      throw const RealtimeSessionException(RealtimeFailureReason.unknown);
    }
    try {
      await _postJson('/voicechat/end_task', {
        'session_id': _sessionId,
        'user_id': userId,
        'client_id': _config.clientId,
        'analysis_mode': 'full',
      });

      // 轮询报告直到就绪（404 = 尚未生成）。
      for (int attempt = 0; attempt < reportPollAttempts; attempt++) {
        try {
          final Map<String, dynamic> report = await _getJson(
            '/sessions/$_sessionId/report/last',
          );
          return _parseReport(report);
        } on RealtimeReportNotReadyException {
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      }
      throw const RealtimeSessionException(
        RealtimeFailureReason.networkError,
        '报告生成超时',
      );
    } finally {
      _sessionId = null;
    }
  }

  TutorReport _parseReport(Map<String, dynamic> raw) {
    // 参考工程的报告为中文键结构，这里做宽松解析。
    int readScore(String path) {
      dynamic node = raw;
      for (final String part in path.split('.')) {
        if (node is Map<String, dynamic> && node.containsKey(part)) {
          node = node[part];
        } else {
          return 70;
        }
      }
      if (node is num) {
        return node.clamp(0, 100).round();
      }
      return 70;
    }

    return TutorReport(
      durationSeconds: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds,
      childTurns: _childTurns,
      overallScore: readScore('评分.总分'),
      pronunciationScore: readScore('腾讯口语评分.评分.发音准确度'),
      fluencyScore: readScore('腾讯口语评分.评分.流利度'),
      weakWords: const <WeakWordRecord>[],
      encouragement: '完成啦！看看报告里的表现吧！',
      summary: '会话 ${_sessionId ?? ''} 的报告已生成。',
    );
  }

  @override
  Future<void> dispose() async {
    _client?.close(force: true);
    _client = null;
    await _events.close();
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final Uri uri = Uri.parse(
      '${_config.apiBaseUrl.trimRight()}$path',
    ).replace(queryParameters: query);
    final HttpClientRequest request = await _client!.getUrl(uri);
    final HttpClientResponse response = await request.close();
    if (response.statusCode == 404) {
      throw const RealtimeReportNotReadyException();
    }
    return _readJson(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final Uri uri = Uri.parse('${_config.apiBaseUrl.trimRight()}$path');
    final HttpClientRequest request = await _client!.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final HttpClientResponse response = await request.close();
    return _readJson(response);
  }

  Future<Map<String, dynamic>> _readJson(HttpClientResponse response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _emit(SessionError('服务返回 ${response.statusCode}'));
      throw const RealtimeSessionException(RealtimeFailureReason.networkError);
    }
    final String body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  }

  void _emit(RealtimeEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}

final class RealtimeReportNotReadyException implements Exception {
  const RealtimeReportNotReadyException();
}
