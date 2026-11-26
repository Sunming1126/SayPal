import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../realtime/voice/conversation_context.dart';
import '../../realtime/voice/pages/practice_conversation_page.dart';
import '../../vocabulary/providers/vocabulary_providers.dart';
import '../../vocabulary/widgets/word_lookup_sheet.dart';
import '../models/theme_course.dart';
import '../providers/theme_course_providers.dart';

class ThemeCoursePage extends ConsumerWidget {
  const ThemeCoursePage({required this.courseId, super.key});
  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(themeCoursesProvider).when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (_, __) => const Scaffold(
              body: ErrorStateView(title: '课程加载失败', message: '')),
          data: (List<ThemeCourse> courses) {
            final List<ThemeCourse> found = courses
                .where((ThemeCourse item) => item.id == courseId)
                .toList();
            if (found.isEmpty) {
              return const Scaffold(
                  body: ErrorStateView(title: '课程不存在', message: ''));
            }
            return _ThemeCourseBody(course: found.first);
          },
        );
  }
}

class _ThemeCourseBody extends ConsumerStatefulWidget {
  const _ThemeCourseBody({required this.course});
  final ThemeCourse course;
  @override
  ConsumerState<_ThemeCourseBody> createState() => _ThemeCourseBodyState();
}

class _ThemeCourseBodyState extends ConsumerState<_ThemeCourseBody> {
  VideoPlayerController? _player;
  List<_Cue> _cues = const <_Cue>[];
  String _caption = '';
  bool _finished = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!widget.course.videoReady) return;
    try {
      final VideoPlayerController player =
          VideoPlayerController.networkUrl(Uri.parse(widget.course.videoUrl));
      _player = player;
      await Future.wait<void>(
          <Future<void>>[player.initialize(), _loadVtt(widget.course.vttUrl)]);
      player.addListener(_listen);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = '视频或字幕暂时无法加载，请检查课程链接。');
    }
  }

  Future<void> _loadVtt(String url) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(Uri.parse(url));
      final HttpClientResponse response = await request.close();
      if (response.statusCode == 200) {
        _cues = _parseVtt(
            await response.transform(const SystemEncoding().decoder).join());
      }
    } finally {
      client.close(force: true);
    }
  }

  void _listen() {
    final VideoPlayerController? player = _player;
    if (player == null || !player.value.isInitialized) return;
    final Duration position = player.value.position;
    final _Cue? cue = _cues.cast<_Cue?>().firstWhere(
          (_Cue? item) =>
              item != null && position >= item.start && position < item.end,
          orElse: () => null,
        );
    final String nextCaption = cue?.text ?? '';
    final bool done = player.value.duration > Duration.zero &&
        position >= player.value.duration;
    if ((nextCaption != _caption || (done && !_finished)) && mounted) {
      setState(() {
        _caption = nextCaption;
        _finished = _finished || done;
      });
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_listen);
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? player = _player;
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(widget.course.subtitle,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                  color: Colors.black, borderRadius: BorderRadius.circular(22)),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: player?.value.isInitialized == true
                    ? player!.value.aspectRatio
                    : 16 / 9,
                child: Stack(alignment: Alignment.center, children: <Widget>[
                  if (!widget.course.videoReady)
                    const _VideoPreparingState()
                  else if (player?.value.isInitialized == true)
                    VideoPlayer(player!)
                  else
                    const CircularProgressIndicator(color: Colors.white),
                  if (_caption.isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Text(_caption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15)),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filledTonal(
                      onPressed: player?.value.isInitialized == true
                          ? () {
                              player!.value.isPlaying
                                  ? player.pause()
                                  : player.play();
                              setState(() {});
                            }
                          : null,
                      icon: Icon(player?.value.isPlaying == true
                          ? Icons.pause
                          : Icons.play_arrow),
                    ),
                  ),
                ]),
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error,
                      style: const TextStyle(color: AppColors.danger))),
            const SizedBox(height: 18),
            const Text('本课单词',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String word in widget.course.vocabulary)
                  ActionChip(
                    label: Text(word),
                    avatar: const Icon(Icons.bookmark_add_outlined, size: 18),
                    onPressed: () => _openWord(word),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('视频中的重点表达',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...widget.course.introLines.map(
              (ThemeCourseLine line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ContentCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(line.en,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(line.zh,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ]),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryActionButton(
              label: !widget.course.videoReady
                  ? '视频准备好后可练习'
                  : _finished
                      ? '开始表达练习'
                      : '请观看完整视频后开始',
              enabled: widget.course.videoReady && _finished,
              icon: Icons.mic_rounded,
              onPressed: () => context.push(
                  '/learning/theme/${widget.course.id}/practice/translation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWord(String word) async {
    final bool saved =
        await ref.read(vocabularyRepositoryProvider).isSaved(word);
    if (!mounted) return;
    await showWordLookupSheet(
      context,
      rawWord: word,
      sheetRef: ref,
      alreadySaved: saved,
      source: '主题课 · ${widget.course.title}',
      wordLookup: (String value) =>
          ref.read(wordLookupServiceProvider).lookup(value),
    );
  }
}

class ThemeCoursePracticePage extends ConsumerWidget {
  const ThemeCoursePracticePage(
      {required this.courseId, required this.stage, super.key});
  final String courseId, stage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeCourseProgressProvider);
    return ref.watch(themeCoursesProvider).when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (_, __) => const Scaffold(
              body: ErrorStateView(title: '课程加载失败', message: '')),
          data: (List<ThemeCourse> courses) {
            final List<ThemeCourse> found = courses
                .where((ThemeCourse item) => item.id == courseId)
                .toList();
            if (found.isEmpty) {
              return const Scaffold(
                  body: ErrorStateView(title: '课程不存在', message: ''));
            }
            final ThemeCourse course = found.first;
            final bool english = stage == 'english';
            final List<String> objectives = english
                ? const <String>['听懂英文问题', '用英文简短回答', '大胆完成五个问答']
                : const <String>['听懂中文句意', '用英文表达重点句', '完成七句表达训练'];
            return PracticeConversationPage(
              context: ConversationContext(
                kind: english
                    ? ConversationKind.tutorEnglishQa
                    : ConversationKind.tutorTranslation,
                catalogId: course.id,
                title: course.title,
                objectives: objectives,
                stageIndex: english ? 2 : 1,
              ),
              welcome: english
                  ? 'We are starting English Q and A. First question: ${course.qaPairs.first.question}'
                  : '我们开始第二部分。我说中文，请你用英文回答。第一题：${course.translationDrill.first.zh}',
              objectives: objectives,
              finishedLabel: english ? '英文问答完成' : '中译英练习完成',
              nextRoute: english
                  ? null
                  : '/learning/theme/${course.id}/practice/english',
              onCompleted: english
                  ? () => ref
                      .read(themeCourseProgressProvider.notifier)
                      .completeCourse(course.id)
                  : null,
            );
          },
        );
  }
}

class _VideoPreparingState extends StatelessWidget {
  const _VideoPreparingState();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF23304A),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(18),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.ondemand_video_rounded, color: Colors.white, size: 42),
            SizedBox(height: 8),
            Text(
              '视频准备中',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              '可以先看看本课单词和重点表达',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
}

class _Cue {
  const _Cue(this.start, this.end, this.text);
  final Duration start, end;
  final String text;
}

List<_Cue> _parseVtt(String source) {
  final List<_Cue> cues = <_Cue>[];
  final List<String> lines = source.replaceAll('\r', '').split('\n');
  for (int index = 0; index < lines.length; index++) {
    if (!lines[index].contains('-->')) continue;
    final List<String> parts = lines[index].split('-->');
    if (parts.length != 2) continue;
    final Duration? start = _time(parts[0]);
    final Duration? end = _time(parts[1].split(' ').first);
    if (start == null || end == null) continue;
    final StringBuffer text = StringBuffer();
    while (++index < lines.length && lines[index].trim().isNotEmpty) {
      text.writeln(lines[index]);
    }
    cues.add(_Cue(start, end, text.toString().trim()));
  }
  return cues;
}

Duration? _time(String raw) {
  final RegExpMatch? match =
      RegExp(r'(?:(\d+):)?(\d+):(\d+)\.(\d+)').firstMatch(raw.trim());
  if (match == null) return null;
  return Duration(
    hours: int.parse(match.group(1) ?? '0'),
    minutes: int.parse(match.group(2)!),
    seconds: int.parse(match.group(3)!),
    milliseconds: int.parse(match.group(4)!.padRight(3, '0').substring(0, 3)),
  );
}
