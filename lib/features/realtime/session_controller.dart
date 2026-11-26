import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/realtime_events.dart';
import 'domain/realtime_models.dart';
import 'domain/realtime_session_state.dart';
import 'domain/realtime_tutor_repository.dart';
import 'realtime_providers.dart';

/// 会话状态机控制器：消费仓库事件流，维护 [RealtimeSessionState]。
/// UI 只读该状态并调用 [start]/[submitReply]/[endSession]。
final class RealtimeSessionController
    extends AutoDisposeFamilyNotifier<RealtimeSessionState,
        RealtimeSessionRequest> {
  StreamSubscription<RealtimeEvent>? _subscription;
  late RealtimeSessionRequest _request;
  RealtimeTutorRepository? _repository;

  @override
  RealtimeSessionState build(RealtimeSessionRequest arg) {
    final factory = ref.watch(realtimeRepositoryFactoryProvider);
    final repository = factory.create();
    _request = arg;
    _repository = repository;
    ref.onDispose(() {
      _repository = null;
      _subscription?.cancel();
      _subscription = null;
      unawaited(repository.dispose());
    });
    return RealtimeSessionState(demoMode: !factory.isRealAvailable);
  }

  /// 启动会话。
  Future<void> start() async {
    final repository = _repository;
    if (repository == null ||
        (state.phase != RealtimeSessionPhase.idle && !state.isFailed)) {
      return;
    }
    state = state.copyWith(
      phase: RealtimeSessionPhase.preparing,
      failureReason: null,
      failureMessage: null,
    );
    try {
      _subscription?.cancel();
      _subscription = repository.events.listen(_handleEvent);
      state = state.copyWith(phase: RealtimeSessionPhase.connecting);
      await repository.startSession(_request);
      if (!identical(_repository, repository) ||
          state.phase != RealtimeSessionPhase.connecting) {
        return;
      }
      state = state.copyWith(
        phase: RealtimeSessionPhase.active,
        startedAt: DateTime.now(),
      );
    } on RealtimeSessionException catch (error) {
      if (!identical(_repository, repository)) return;
      state = state.copyWith(
        phase: RealtimeSessionPhase.failed,
        failureReason: error.reason,
      );
    } on Exception catch (error) {
      if (!identical(_repository, repository)) return;
      state = state.copyWith(
        phase: RealtimeSessionPhase.failed,
        failureReason: RealtimeFailureReason.unknown,
        failureMessage: error.toString(),
      );
    }
  }

  /// 提交孩子的一句话（演示模式：点选示范句或输入）。
  Future<void> submitReply(String text) async {
    final repository = _repository;
    if (repository == null || !state.isActive || text.trim().isEmpty) {
      return;
    }
    state = state.copyWith(suggestions: const <String>[]);
    await repository.sendChildUtterance(text.trim());
  }

  /// 结束会话并取得报告。
  Future<void> endSession() async {
    final repository = _repository;
    if (repository == null ||
        state.isEnded ||
        state.phase == RealtimeSessionPhase.ending) {
      return;
    }
    state = state.copyWith(phase: RealtimeSessionPhase.ending);
    try {
      final TutorReport report = await repository.endSession();
      if (!identical(_repository, repository)) return;
      state = state.copyWith(
        phase: RealtimeSessionPhase.closed,
        report: report,
        suggestions: const <String>[],
        aiSpeaking: false,
      );
    } on RealtimeSessionException catch (error) {
      if (!identical(_repository, repository)) return;
      state = state.copyWith(
        phase: RealtimeSessionPhase.failed,
        failureReason: error.reason,
      );
    }
  }

  void _handleEvent(RealtimeEvent event) {
    switch (event) {
      case AiSpeakingChanged(:final bool isSpeaking):
        state = state.copyWith(aiSpeaking: isSpeaking);
      case ChildSpeakingChanged():
        // MVP 中孩子语音状态暂无 UI 反馈。
        break;
      case TranscriptCommitted(:final TranscriptEntry entry):
        state = state.copyWith(
          transcripts: [...state.transcripts, entry],
        );
      case ExpectingChildReply(:final List<String> suggestions):
        state = state.copyWith(
          suggestions: suggestions,
          currentTurnIndex: suggestions.isNotEmpty ? state.currentTurnIndex : 0,
        );
      case ReplyScored():
        final List<int> scores = List<int>.of(state.turnScores);
        while (scores.length <= event.turnIndex) {
          scores.add(-1);
        }
        scores[event.turnIndex] = event.score;
        state = state.copyWith(turnScores: scores);
      case SessionError():
        state = state.copyWith(
          phase: RealtimeSessionPhase.failed,
          failureReason: RealtimeFailureReason.unknown,
          failureMessage: event.message,
        );
    }
  }
}

final realtimeSessionControllerProvider = NotifierProvider.autoDispose
    .family<RealtimeSessionController, RealtimeSessionState,
        RealtimeSessionRequest>(RealtimeSessionController.new);
