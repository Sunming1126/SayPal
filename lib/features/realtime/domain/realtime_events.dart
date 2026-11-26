import 'realtime_models.dart';

/// 会话事件流：UI 只通过状态机消费这些事件，不直接触碰 RTC SDK。
sealed class RealtimeEvent {
  const RealtimeEvent();
}

/// AI 开始/停止说话（驱动字幕区的说话动效）。
final class AiSpeakingChanged extends RealtimeEvent {
  const AiSpeakingChanged(this.isSpeaking);
  final bool isSpeaking;
}

/// 孩子开始/停止说话。
final class ChildSpeakingChanged extends RealtimeEvent {
  const ChildSpeakingChanged(this.isSpeaking);
  final bool isSpeaking;
}

/// 新字幕提交（一条完整消息，含 AI 欢迎语）。
final class TranscriptCommitted extends RealtimeEvent {
  const TranscriptCommitted(this.entry);
  final TranscriptEntry entry;
}

/// 演示链路：提示孩子可以开口了，并给出可选的示范回答。
final class ExpectingChildReply extends RealtimeEvent {
  const ExpectingChildReply({required this.suggestions, this.turnIndex = 0});
  final List<String> suggestions;
  final int turnIndex;
}

/// 演示链路：对孩子的回答给出的即时评分（学一学/角色扮演用于推进任务）。
final class ReplyScored extends RealtimeEvent {
  const ReplyScored({
    required this.turnIndex,
    required this.score,
    required this.matchedKeywords,
    required this.missedKeywords,
  });
  final int turnIndex;
  final int score;
  final List<String> matchedKeywords;
  final List<String> missedKeywords;
}

/// 会话出错（未配置服务、网络失败等，具体原因由状态机记录）。
final class SessionError extends RealtimeEvent {
  const SessionError(this.message);
  final String message;
}
