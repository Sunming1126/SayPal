import 'dart:async';

import 'dart:math' as math;

import '../../../core/models/scored_reply.dart';
import '../domain/realtime_events.dart';
import '../domain/realtime_models.dart';
import '../domain/realtime_tutor_repository.dart';

/// 离线演示实现：不连接任何 RTC 房间，用脚本驱动"AI 提问 → 孩子点选/输入回答"
/// 的完整体验，并按关键词给出温和的演示评分。
/// 所有 UI 都必须展示 [DemoBadge] 标明这是离线演示。
final class DemoRealtimeTutorRepository implements RealtimeTutorRepository {
  DemoRealtimeTutorRepository({this.randomSeed});

  /// 便于测试注入固定随机源。
  final math.Random? randomSeed;

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();
  final List<int> _turnScores = <int>[];
  final List<WeakWordRecord> _weakWords = <WeakWordRecord>[];

  RealtimeSessionRequest? _request;
  int _turnIndex = 0;
  int _childTurns = 0;
  DateTime? _startedAt;
  bool _awaitingReply = false;
  Timer? _speakingTimer;

  @override
  bool get supportsTextInput => true;

  @override
  Stream<RealtimeEvent> get events => _events.stream;

  @override
  Future<void> startSession(RealtimeSessionRequest request) async {
    _request = request;
    _turnIndex = 0;
    _childTurns = 0;
    _turnScores.clear();
    _weakWords.clear();
    _awaitingReply = false;
    _startedAt = DateTime.now();

    // 模拟准备 → 连接的短暂过程（演示形态，不接通任何真实服务）。
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (request.script.isEmpty) {
      _emit(const SessionError('演示脚本为空'));
      return;
    }
    _playAiTurn();
  }

  /// 播放第 _turnIndex 轮 AI 台词。
  void _playAiTurn() {
    if (_events.isClosed || _startedAt == null) return;
    final List<DemoScriptTurn> script = _request!.script;
    if (_turnIndex >= script.length) {
      _finishScript();
      return;
    }
    final DemoScriptTurn turn = script[_turnIndex];
    _emit(const AiSpeakingChanged(true));

    // 模拟 AI 说这句话的时长（每 6 个字符约 0.35s，上下限保护）。
    final int speakMs =
        math.max(500, math.min(2200, turn.aiTextEn.length * 58));
    _speakingTimer = Timer(Duration(milliseconds: speakMs), () {
      _emit(const AiSpeakingChanged(false));
      _emit(
        TranscriptCommitted(
          TranscriptEntry(
            id: 'ai-$_turnIndex',
            speaker: TranscriptSpeaker.ai,
            text: turn.aiTextEn,
            zhHint: turn.aiTextZh,
          ),
        ),
      );
      _awaitingReply = true;
      _emit(
        ExpectingChildReply(suggestions: turn.suggestions, turnIndex: _turnIndex),
      );
    });
  }

  @override
  Future<void> sendChildUtterance(String text) async {
    if (!_awaitingReply || _request == null) {
      return;
    }
    final List<DemoScriptTurn> script = _request!.script;
    final DemoScriptTurn turn = script[_turnIndex];

    _awaitingReply = false;
    _childTurns += 1;
    _emit(
      TranscriptCommitted(
        TranscriptEntry(
          id: 'child-$_turnIndex',
          speaker: TranscriptSpeaker.child,
          text: text,
        ),
      ),
    );

    if (turn.keywords.isNotEmpty) {
      final ReplyScore score = scoreReplyByKeywords(text, turn.keywords);
      _turnScores.add(score.score);
      _weakWords.addAll(
        score.missedKeywords.map(
          (String w) => WeakWordRecord(word: w, reason: '本轮回答中缺少该词'),
        ),
      );
      _emit(
        ReplyScored(
          turnIndex: _turnIndex,
          score: score.score,
          matchedKeywords: score.matchedKeywords,
          missedKeywords: score.missedKeywords,
        ),
      );
    } else {
      // 自由聊天不评分，记录一个满分占位以保持轮次对齐。
      _turnScores.add(-1);
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    _turnIndex += 1;
    _playAiTurn();
  }

  void _finishScript() {
    // 脚本播完后保持会话可继续（自由聊天可循环最后几轮），由调用方决定结束。
    _awaitingReply = false;
  }

  @override
  Future<TutorReport> endSession() async {
    _speakingTimer?.cancel();
    final DateTime endedAt = DateTime.now();
    final int durationSeconds = _startedAt == null
        ? 0
        : math.max(1, endedAt.difference(_startedAt!).inSeconds);
    _startedAt = null;

    final List<int> scored = _turnScores.where((int s) => s >= 0).toList();
    final int overall = scored.isEmpty
        ? 80
        : (scored.reduce((int a, int b) => a + b) / scored.length).round();
    final int fluency = math.max(
      40,
      math.min(98, overall + (randomSeed?.nextInt(5) ?? 3)),
    );
    final int pronunciation = math.max(
      40,
      math.min(98, overall + (randomSeed?.nextInt(7) ?? 2) - 2),
    );

    _awaitingReply = false;
    return TutorReport(
      durationSeconds: durationSeconds,
      childTurns: _childTurns,
      overallScore: overall,
      pronunciationScore: pronunciation,
      fluencyScore: fluency,
      weakWords: List.unmodifiable(_weakWords),
      encouragement: encouragementFor(overall),
      summary: _request == null
          ? null
          : '本次共完成 $_childTurns 轮对话（演示评分，仅供参考）。篇幅有限，继续加油！',
    );
  }

  @override
  Future<void> dispose() async {
    _speakingTimer?.cancel();
    await _events.close();
  }

  void _emit(RealtimeEvent event) {
    if (!_events.isClosed) {
      _events.add(event);
    }
  }
}
