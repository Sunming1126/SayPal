import 'dart:async';

import 'realtime_events.dart';
import 'realtime_models.dart';
import 'realtime_session_state.dart';

/// 演示脚本中的一轮对话：AI 先说，孩子再回答。
class DemoScriptTurn {
  const DemoScriptTurn({
    required this.aiTextEn,
    this.aiTextZh,
    required this.suggestions,
    this.keywords = const <String>[],
    this.taskId,
  });

  final String aiTextEn;
  final String? aiTextZh;

  /// 给孩子选择的示范回答（离线演示中没有真实语音识别）。
  final List<String> suggestions;

  /// 期望命中的关键词（空列表表示自由聊天，不评分）。
  final List<String> keywords;

  /// 可选：该轮对应的学习步骤/情景任务 id。
  final String? taskId;
}

/// 会话启动请求。
class RealtimeSessionRequest {
  const RealtimeSessionRequest({
    required this.sessionId,
    required this.tutorName,
    this.tutorPersonaPrompt,
    this.script = const <DemoScriptTurn>[],
  });

  /// 会话唯一标识（同屏重建时保持稳定）。
  final String sessionId;
  final String tutorName;

  /// AI 角色提示词（真实链路拼入 system prompt）。
  final String? tutorPersonaPrompt;

  /// 演示脚本（真实链路忽略）。
  final List<DemoScriptTurn> script;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is RealtimeSessionRequest && other.sessionId == sessionId;

  @override
  int get hashCode => sessionId.hashCode;
}

/// 统一的实时陪练会话仓库抽象。
/// UI 与各 feature 只依赖该接口；真实 RTC 链路在 `features/realtime` 内实现。
abstract interface class RealtimeTutorRepository {
  /// 演示实现支持文字回答；真实链路只支持语音。
  bool get supportsTextInput;

  /// 事件流（字幕、说话状态、评分、错误）。
  Stream<RealtimeEvent> get events;

  /// 拉起会话：真实链路 = 获取会话配置 → 加入 RTC 房间 → 启动语音会话。
  Future<void> startSession(RealtimeSessionRequest request);

  /// 孩子的一句话（真实链路来自语音识别提交/字幕段落，演示链路来自点选或输入）。
  Future<void> sendChildUtterance(String text);

  /// 结束会话并等待报告。
  Future<TutorReport> endSession();

  /// 释放资源（离开房间、关闭连接）。
  Future<void> dispose();
}

/// 会话仓库工厂：根据运行时配置选择演示/真实实现。
abstract interface class RealtimeTutorRepositoryFactory {
  /// 未配置真实服务时必须返回演示实现。
  RealtimeTutorRepository create();

  /// 是否已具备真实服务配置。
  bool get isRealAvailable;
}

/// 会话异常（携带用户可理解的失败原因）。
final class RealtimeSessionException implements Exception {
  const RealtimeSessionException(this.reason, [this.message]);
  final RealtimeFailureReason reason;
  final String? message;

  @override
  String toString() => 'RealtimeSessionException(${reason.name}: $message)';
}
