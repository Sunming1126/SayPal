import 'realtime_models.dart';

/// 会话阶段。
enum RealtimeSessionPhase {
  /// 未开始。
  idle,

  /// 准备中（获取会话配置、bootstrap）。
  preparing,

  /// 连接 RTC 房间 / 启动语音链路。
  connecting,

  /// 会话进行中。
  active,

  /// 正在结束会话并生成报告。
  ending,

  /// 已结束（report 就绪）。
  closed,

  /// 失败。
  failed,
}

/// 失败原因（用户可理解，不泄露配置内容）。
enum RealtimeFailureReason {
  serviceNotConfigured,
  micPermissionDenied,
  networkError,
  unknown,
}

/// 会话状态机的不可变快照。
class RealtimeSessionState {
  const RealtimeSessionState({
    this.phase = RealtimeSessionPhase.idle,
    this.transcripts = const <TranscriptEntry>[],
    this.suggestions = const <String>[],
    this.currentTurnIndex = 0,
    this.turnScores = const <int>[],
    this.aiSpeaking = false,
    this.report,
    this.failureReason,
    this.failureMessage,
    this.startedAt,
    this.demoMode = true,
  });

  final RealtimeSessionPhase phase;
  final List<TranscriptEntry> transcripts;

  /// 演示链路：等待孩子回答时给出的示范句。
  final List<String> suggestions;

  /// 当前脚本轮次。
  final int currentTurnIndex;

  /// 每轮回答的演示评分（-1 表示未评分）。
  final List<int> turnScores;

  final bool aiSpeaking;
  final TutorReport? report;
  final RealtimeFailureReason? failureReason;
  final String? failureMessage;
  final DateTime? startedAt;

  /// 当前会话是否为离线演示。
  final bool demoMode;

  RealtimeSessionState copyWith({
    RealtimeSessionPhase? phase,
    List<TranscriptEntry>? transcripts,
    List<String>? suggestions,
    int? currentTurnIndex,
    List<int>? turnScores,
    bool? aiSpeaking,
    TutorReport? report,
    RealtimeFailureReason? failureReason,
    String? failureMessage,
    DateTime? startedAt,
    bool? demoMode,
  }) {
    return RealtimeSessionState(
      phase: phase ?? this.phase,
      transcripts: transcripts ?? this.transcripts,
      suggestions: suggestions ?? this.suggestions,
      currentTurnIndex: currentTurnIndex ?? this.currentTurnIndex,
      turnScores: turnScores ?? this.turnScores,
      aiSpeaking: aiSpeaking ?? this.aiSpeaking,
      report: report ?? this.report,
      failureReason: failureReason ?? this.failureReason,
      failureMessage: failureMessage ?? this.failureMessage,
      startedAt: startedAt ?? this.startedAt,
      demoMode: demoMode ?? this.demoMode,
    );
  }

  bool get isFailed => phase == RealtimeSessionPhase.failed;
  bool get isActive => phase == RealtimeSessionPhase.active;
  bool get isEnded => phase == RealtimeSessionPhase.closed;
  bool get awaitingChildReply => phase == RealtimeSessionPhase.active &&
      suggestions.isNotEmpty;

  /// 失败态对应的中文提示（不泄露任何配置内容）。
  String get failureZhText {
    switch (failureReason) {
      case RealtimeFailureReason.serviceNotConfigured:
        return '实时语音服务还没有配置好，暂时只能使用离线演示内容。';
      case RealtimeFailureReason.micPermissionDenied:
        return '还没有麦克风权限，请在系统设置里允许 SayPal 使用麦克风。';
      case RealtimeFailureReason.networkError:
        return '网络连接不太顺畅，请稍后再试一次。';
      case RealtimeFailureReason.unknown:
      case null:
        return '出了点小问题，请稍后再试一次。';
    }
  }
}
