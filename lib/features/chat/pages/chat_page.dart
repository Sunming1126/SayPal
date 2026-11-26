import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../realtime/domain/realtime_models.dart';
import '../../realtime/domain/realtime_session_state.dart';
import '../../realtime/domain/realtime_tutor_repository.dart';
import '../../realtime/session_controller.dart';
import '../../realtime/widgets/session_stage.dart';
import '../../statistics/providers/statistics_providers.dart';
import '../../vocabulary/providers/vocabulary_providers.dart';
import '../../vocabulary/widgets/word_lookup_sheet.dart';
import '../data/seed_personas.dart';
import '../models/chat_persona.dart';
import '../providers/chat_providers.dart';
import '../widgets/persona_picker_sheet.dart';

/// 聊一聊：儿童化自由对话。
/// 未配置真实服务时使用离线演示脚本，且界面始终显示演示标识。
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  bool _showTranslations = true;
  bool _recordingStats = false;

  RealtimeSessionRequest _request() =>
      ref.read(chatSessionRequestProvider);

  @override
  Widget build(BuildContext context) {
    final ChatPersona persona = ref.watch(selectedPersonaProvider);
    final RealtimeSessionRequest request = ref.watch(chatSessionRequestProvider);
    final RealtimeSessionState state =
        ref.watch(realtimeSessionControllerProvider(request));

    // 进入页面 / 切换角色后自动拉起会话。
    if (state.phase == RealtimeSessionPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(realtimeSessionControllerProvider(request)).phase ==
                RealtimeSessionPhase.idle) {
          ref
              .read(realtimeSessionControllerProvider(request).notifier)
              .start();
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('聊一聊'),
        actions: [
          IconButton(
            tooltip: '看/藏中文翻译',
            icon: Icon(
              _showTranslations ? Icons.translate : Icons.translate_outlined,
              color: AppColors.primary,
            ),
            onPressed: () =>
                setState(() => _showTranslations = !_showTranslations),
          ),
          IconButton(
            tooltip: '口语纠错',
            icon: const Icon(
              Icons.spellcheck_outlined,
              color: AppColors.primary,
            ),
            onPressed: () => _showCorrectionSheet(state),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Flexible(
                    child: _PersonaChip(
                      persona: persona,
                      onTap: () => showPersonaPickerSheet(
                        context,
                        personas: kSeedPersonas,
                        selected: persona,
                        onSelected: (ChatPersona next) {
                          ref.read(selectedPersonaProvider.notifier).select(next);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const DemoBadge(),
                ],
              ),
            ),
            Expanded(
              child: SessionStage(
                state: state,
                showTranslations: _showTranslations,
                onWordTap: (String word) async {
                  final bool saved =
                      await ref.read(vocabularyRepositoryProvider).isSaved(word);
                  if (!context.mounted) {
                    return;
                  }
                  await showWordLookupSheet(
                    context,
                    rawWord: word,
                    sheetRef: ref,
                    alreadySaved: saved,
                    source: '聊一聊',
                    wordLookup: (String w) => ref
                        .read(wordLookupServiceProvider)
                        .lookup(w),
                  );
                },
                onSubmitReply: (String text) =>
                    ref
                        .read(realtimeSessionControllerProvider(request).notifier)
                        .submitReply(text),
                onEndSession: () => _endSession(request),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endSession(RealtimeSessionRequest request) async {
    if (_recordingStats) {
      return;
    }
    _recordingStats = true;
    final controller =
        ref.read(realtimeSessionControllerProvider(request).notifier);
    await controller.endSession();
    final RealtimeSessionState state =
        ref.read(realtimeSessionControllerProvider(request));
    final TutorReport? report = state.report;
    if (report != null) {
      await recordFinishedSession(
        ref,
        feature: '聊一聊',
        durationSeconds: report.durationSeconds,
        speakingTurns: report.childTurns,
        pronunciationScore: report.pronunciationScore,
        fluencyScore: report.fluencyScore,
        weakWords: report.weakWords.map((WeakWordRecord w) => w.word).toList(),
      );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext dialogContext) => _ChatReportDialog(
            report: report,
            personaName: _request().tutorName,
          ),
        );
        // 重置会话，回到打招呼状态。
        ref.invalidate(realtimeSessionControllerProvider(_request()));
      }
    }
    _recordingStats = false;
  }

  void _showCorrectionSheet(RealtimeSessionState state) {
    final List<String> childLines = state.transcripts
        .where((TranscriptEntry e) => e.speaker == TranscriptSpeaker.child)
        .map((TranscriptEntry e) => e.text)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: '口语小检查'),
              if (!AppConfig.instance.isDemoMode)
                const Text('真实纠错将在服务接通后提供。')
              else if (childLines.isEmpty)
                const Text(
                  '先和小老师说几句话，再来检查吧！',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                for (final String line in childLines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            line,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
              if (AppConfig.instance.isDemoMode && childLines.isNotEmpty)
                const Text(
                  '（演示模式：这里只做简单示范，真实纠错要等服务接通哦）',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonaChip extends StatelessWidget {
  const _PersonaChip({required this.persona, required this.onTap});

  final ChatPersona persona;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: persona.color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(persona.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${persona.name} · ${persona.voiceLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: persona.color,
                  ),
                ),
              ),
              const Icon(Icons.expand_more, size: 18, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatReportDialog extends StatelessWidget {
  const _ChatReportDialog({required this.report, required this.personaName});

  final TutorReport report;
  final String personaName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('和$personaName的对话小结'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('聊了 ${report.durationSeconds} 秒，开口 ${report.childTurns} 次。'),
          const SizedBox(height: 8),
          Text('演示评分：综合 ${report.overallScore} 分'),
          const SizedBox(height: 8),
          Text(
            report.encouragement,
            style: const TextStyle(color: AppColors.success),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('好耶'),
        ),
      ],
    );
  }
}
