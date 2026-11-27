import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/widgets/common_widgets.dart';
import '../../realtime/voice/conversation_context.dart';
import '../../realtime/voice/pages/practice_conversation_page.dart';
import '../../realtime/voice/voice_conversation_providers.dart';
import '../data/video_roleplay_lessons.dart';

class VideoRoleplayCatalogPage extends ConsumerStatefulWidget {
  const VideoRoleplayCatalogPage({super.key});

  @override
  ConsumerState<VideoRoleplayCatalogPage> createState() =>
      _VideoRoleplayCatalogPageState();
}

class _VideoRoleplayCatalogPageState
    extends ConsumerState<VideoRoleplayCatalogPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) => _VideoCatalogScaffold(
    content: (lessons) {
      final matching = lessons
          .where((lesson) {
            return '${lesson.title} ${lesson.englishTitle}'
                .toLowerCase()
                .contains(_query);
          })
          .toList(growable: false);
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索 ${lessons.length} 节视频课',
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: matching.isEmpty
                ? const Center(child: Text('没有找到匹配的课程'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: matching.length,
                    itemBuilder: (context, index) {
                      final lesson = matching[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 8,
                          ),
                          leading: const Icon(
                            Icons.play_circle_outline_rounded,
                          ),
                          title: Text(lesson.title),
                          subtitle: Text(lesson.englishTitle),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push(lesson.route),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}

class VideoRoleplayLessonPage extends ConsumerWidget {
  const VideoRoleplayLessonPage({required this.lessonId, super.key});

  final String lessonId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref
        .watch(videoRoleplayLessonsProvider)
        .valueOrNull
        ?.where((lesson) => lesson.id == lessonId)
        .firstOrNull;
    if (lesson != null) return VideoRoleplayPage(lesson: lesson);
    return _VideoCatalogScaffold(
      content: (_) => const Center(child: Text('这节视频课暂不可用')),
    );
  }
}

class _VideoCatalogScaffold extends ConsumerWidget {
  const _VideoCatalogScaffold({required this.content});

  final Widget Function(List<VideoRoleplayLesson>) content;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('视频情景陪练')),
    body: ref
        .watch(videoRoleplayLessonsProvider)
        .when(
          data: content,
          loading: () => const LoadingView(),
          error: (_, _) => ErrorStateView(
            title: '暂时无法加载视频课',
            message: '请检查网络后重试。',
            onRetry: () => ref.invalidate(videoRoleplayLessonsProvider),
          ),
        ),
  );
}

class VideoRoleplayPage extends ConsumerStatefulWidget {
  const VideoRoleplayPage({required this.lesson, super.key});

  final VideoRoleplayLesson lesson;

  @override
  ConsumerState<VideoRoleplayPage> createState() => _VideoRoleplayPageState();
}

class _VideoRoleplayPageState extends ConsumerState<VideoRoleplayPage>
    with WidgetsBindingObserver {
  late final ConversationContext _context = widget.lesson.toContext();
  VideoPlayerController? _player;
  bool _videoError = false;
  bool _watched = false;
  bool _preparing = false;
  bool _practicing = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadVideo());
  }

  Future<void> _loadVideo() async {
    _disposePlayer();
    final player = VideoPlayerController.networkUrl(widget.lesson.videoUri);
    _player = player;
    setState(() => _videoError = false);
    try {
      await player.initialize().timeout(const Duration(seconds: 15));
      if (!mounted || !identical(_player, player)) return;
      player.addListener(_onVideoChanged);
      setState(() {});
    } catch (_) {
      if (mounted && identical(_player, player)) {
        setState(() => _videoError = true);
      }
    }
  }

  void _onVideoChanged() {
    final value = _player!.value;
    if (value.isCompleted && !_watched) {
      setState(() => _watched = true);
    }
    if (!_foreground || _preparing || value.hasError) return;
    if (value.isCompleted ||
        (value.isPlaying &&
            value.position > Duration.zero &&
            value.duration - value.position <= const Duration(seconds: 12))) {
      _preparing = true;
      unawaited(
        ref.read(voiceConversationProvider(_context).notifier).connect(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_practicing) return;
    _foreground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_player?.pause());
      if (_preparing) {
        _preparing = false;
        unawaited(
          ref.read(voiceConversationProvider(_context).notifier).pause(),
        );
      }
    }
  }

  void _disposePlayer() {
    final player = _player;
    _player = null;
    player?.removeListener(_onVideoChanged);
    unawaited(player?.dispose());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposePlayer();
    super.dispose();
  }

  Future<void> _togglePlayback(VideoPlayerController player) async {
    try {
      if (player.value.isPlaying) {
        await player.pause();
      } else {
        if (player.value.isCompleted) await player.seekTo(Duration.zero);
        await player.play();
      }
    } catch (_) {
      if (mounted && identical(_player, player)) {
        setState(() => _videoError = true);
      }
    }
  }

  void _startPractice() {
    _disposePlayer();
    unawaited(
      ref
          .read(voiceConversationProvider(_context).notifier)
          .activate(keepConnected: true),
    );
    setState(() => _practicing = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_practicing) {
      return PracticeConversationPage(
        context: _context,
        welcome: widget.lesson.opening,
        objectives: widget.lesson.objectives,
        finishedLabel: '视频情景陪练结束',
        showFavorite: false,
      );
    }

    // Hold the warm connection until the conversation page watches it.
    ref.listen(voiceConversationProvider(_context), (_, _) {});
    final player = _player;
    return Scaffold(
      appBar: AppBar(title: Text(widget.lesson.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _videoError || player == null
                    ? _playbackError()
                    : ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: player,
                        builder: (context, value, _) {
                          if (value.hasError) return _playbackError();
                          if (!value.isInitialized) {
                            return const CircularProgressIndicator();
                          }
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(child: VideoPlayer(player)),
                                    IconButton.filled(
                                      tooltip: value.isPlaying
                                          ? '暂停'
                                          : value.isCompleted
                                          ? '重播'
                                          : '播放',
                                      iconSize: 32,
                                      onPressed: () => _togglePlayback(player),
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause_rounded
                                            : value.isCompleted
                                            ? Icons.replay_rounded
                                            : Icons.play_arrow_rounded,
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: VideoProgressIndicator(
                                        player,
                                        allowScrubbing: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _watched ? _startPractice : null,
                  icon: const Icon(Icons.record_voice_over_outlined),
                  label: Text(_watched ? '开始 AI 陪练' : '看完视频后开始陪练'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playbackError() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('暂时无法播放教学视频'),
      TextButton(onPressed: _loadVideo, child: const Text('重试')),
    ],
  );
}
