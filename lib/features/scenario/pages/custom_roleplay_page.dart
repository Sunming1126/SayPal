import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../realtime/voice/conversation_context.dart';
import '../../realtime/voice/pages/practice_conversation_page.dart';
import '../models/practice_catalog.dart';
import '../providers/practice_providers.dart';

class CustomRoleplayPage extends ConsumerStatefulWidget {
  const CustomRoleplayPage({this.showSaved = false, super.key});
  final bool showSaved;

  @override
  ConsumerState<CustomRoleplayPage> createState() => _CustomRoleplayPageState();
}

class _CustomRoleplayPageState extends ConsumerState<CustomRoleplayPage> {
  final TextEditingController _learner = TextEditingController();
  final TextEditingController _ai = TextEditingController();
  final TextEditingController _situation = TextEditingController();
  final TextEditingController _title = TextEditingController();
  final List<TextEditingController> _goals =
      List<TextEditingController>.generate(3, (_) => TextEditingController());
  bool _busy = false;
  bool _previewCurrent = false;
  bool _localFallback = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    for (final TextEditingController controller
        in <TextEditingController>[_learner, _ai, _situation]) {
      controller.addListener(_markPreviewStale);
    }
    for (final TextEditingController controller
        in <TextEditingController>[_title, ..._goals]) {
      controller.addListener(_refreshPreview);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _learner,
      _ai,
      _situation,
      _title,
      ..._goals,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _seedComplete => _learner.text.trim().isNotEmpty &&
      _ai.text.trim().isNotEmpty &&
      _situation.text.trim().isNotEmpty;
  bool get _previewComplete => _previewCurrent &&
      _title.text.trim().isNotEmpty &&
      _goals.every((TextEditingController item) => item.text.trim().isNotEmpty);

  void _markPreviewStale() {
    if (!mounted) return;
    setState(() {
      if (_previewCurrent) _previewCurrent = false;
      _error = '';
    });
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showSaved) return _SavedScenes(onSelect: _open);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF7F8FD),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF1F0FF),
              Color(0xFFF8FAFF),
              Color(0xFFF5F7FB),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _CreateHeader(
                busy: _busy,
                enabled: _seedComplete,
                onBack: () => Navigator.of(context).maybePop(),
                onGenerate: _generate,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                  children: <Widget>[
                    const Text(
                      '创建你的情境',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SeedCard(
                      learner: _learner,
                      ai: _ai,
                      situation: _situation,
                    ),
                    if (_busy) ...<Widget>[
                      const SizedBox(height: 18),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                    if (_error.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        _error,
                        key: const ValueKey<String>('custom-scene-error'),
                        style: TextStyle(
                          color: _localFallback
                              ? AppColors.textSecondary
                              : AppColors.danger,
                          height: 1.4,
                        ),
                      ),
                    ],
                    if (_title.text.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 20),
                      _PreviewCard(
                        title: _title,
                        goals: _goals,
                        current: _previewCurrent,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: FilledButton(
          key: const ValueKey<String>('custom-scene-start'),
          onPressed: !_busy && _previewComplete ? _start : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            shape: const StadiumBorder(),
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: const Color(0xFFDCDCFB),
          ),
          child: const Text(
            '开始对话',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  Future<void> _generate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_seedComplete) {
      setState(() => _error = '请先填写双方角色和情境细节。');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
      _localFallback = false;
    });
    try {
      final CustomSceneDraft draft =
          await ref.read(sceneDraftRepositoryProvider).generate(
                SceneDraftSeed(
                  learnerRole: _learner.text,
                  aiRole: _ai.text,
                  situation: _situation.text,
                ),
              );
      if (!mounted) return;
      _title.text = draft.title;
      for (var index = 0; index < _goals.length; index++) {
        _goals[index].text = draft.objectives[index];
      }
      setState(() {
        _previewCurrent = true;
        _localFallback = draft.id.startsWith('local-draft-');
        _error = _localFallback
            ? '在线生成暂时不可用，已准备一份可编辑的本机草稿。'
            : '';
      });
    } catch (_) {
      if (mounted) setState(() => _error = '生成失败，请稍后重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    if (!_previewComplete) return;
    final CustomSceneDraft draft = CustomSceneDraft(
      id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
      title: _title.text.trim(),
      learnerRole: _learner.text.trim(),
      aiRole: _ai.text.trim(),
      situation: _situation.text.trim(),
      objectives: _goals
          .map((TextEditingController item) => item.text.trim())
          .toList(growable: false),
      createdAt: DateTime.now(),
    );
    await ref.read(customSceneRepositoryProvider).save(draft);
    ref.invalidate(customScenesProvider);
    if (mounted) _open(draft);
  }

  void _open(CustomSceneDraft draft) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeConversationPage(
          context: ConversationContext(
            kind: ConversationKind.customRoleplay,
            catalogId: draft.id,
            title: draft.title,
            learnerRole: draft.learnerRole,
            aiRole: draft.aiRole,
            situation: draft.situation,
            objectives: draft.objectives,
          ),
          welcome: 'Hi! I am your ${draft.aiRole}. Let’s begin!',
          objectives: draft.objectives,
          finishedLabel: '自定义情景练习结束',
        ),
      ),
    );
  }
}

class _CreateHeader extends StatelessWidget {
  const _CreateHeader({
    required this.busy,
    required this.enabled,
    required this.onBack,
    required this.onGenerate,
  });
  final bool busy;
  final bool enabled;
  final VoidCallback onBack;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        child: SizedBox(
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              const Text(
                '创建自己的情景',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: GlassIconButton(
                  key: const ValueKey<String>('custom-scene-back'),
                  size: 46,
                  iconSize: 24,
                  useOwnLayer: true,
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  key: const ValueKey<String>('custom-scene-generate'),
                  onPressed: enabled && !busy ? onGenerate : null,
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    minimumSize: const Size(100, 44),
                  ),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 19),
                  label: Text(busy ? '生成中' : '生成'),
                ),
              ),
            ],
          ),
        ),
      );
}

class _SeedCard extends StatelessWidget {
  const _SeedCard({
    required this.learner,
    required this.ai,
    required this.situation,
  });
  final TextEditingController learner;
  final TextEditingController ai;
  final TextEditingController situation;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('custom-scene-seed-card'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.outline),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: <Widget>[
            _SeedField(
              key: const ValueKey<String>('custom-scene-learner'),
              controller: learner,
              icon: Icons.person_outline_rounded,
              hint: '你的角色',
              maxLength: 50,
            ),
            const Divider(height: 1),
            _SeedField(
              key: const ValueKey<String>('custom-scene-ai'),
              controller: ai,
              icon: Icons.support_agent_rounded,
              hint: 'AI 的角色',
              maxLength: 50,
            ),
            const Divider(height: 1),
            _SeedField(
              key: const ValueKey<String>('custom-scene-situation'),
              controller: situation,
              icon: Icons.subject_rounded,
              hint: '补充对话情境、地点和练习内容',
              maxLength: 240,
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
      );
}

class _SeedField extends StatelessWidget {
  const _SeedField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    super.key,
  });
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final int maxLength;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: TextField(
          controller: controller,
          maxLength: maxLength,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            icon: Icon(icon, color: AppColors.textSecondary),
            hintText: hint,
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
      );
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.goals,
    required this.current,
  });
  final TextEditingController title;
  final List<TextEditingController> goals;
  final bool current;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('custom-scene-preview'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: current ? AppColors.outline : const Color(0xFFFFC98B),
          ),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    '场景预览',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  current ? '可编辑' : '请重新生成',
                  style: TextStyle(
                    color: current ? AppColors.primary : AppColors.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey<String>('custom-scene-title'),
              controller: title,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: '场景名称',
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            const Text('练习目标', style: TextStyle(fontWeight: FontWeight.w800)),
            ...List<Widget>.generate(
              goals.length,
              (int index) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  key: ValueKey<String>('custom-scene-goal-$index'),
                  controller: goals[index],
                  maxLength: 60,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppColors.primary.withValues(alpha: .75),
                    ),
                    hintText: '目标 ${index + 1}',
                    counterText: '',
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _SavedScenes extends ConsumerWidget {
  const _SavedScenes({required this.onSelect});
  final void Function(CustomSceneDraft) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('我的自定义场景')),
        body: ref.watch(customScenesProvider).when(
              loading: () => const LoadingView(),
              error: (_, __) =>
                  const ErrorStateView(title: '读取失败', message: '请稍后再试。'),
              data: (List<CustomSceneDraft> items) => items.isEmpty
                  ? const _SavedScenesEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) {
                        final CustomSceneDraft draft = items[index];
                        return ContentCard(
                          onTap: () => onSelect(draft),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                draft.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${draft.learnerRole} · ${draft.aiRole}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                draft.situation,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      );
}

class _SavedScenesEmpty extends StatelessWidget {
  const _SavedScenesEmpty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.bookmark_border_rounded,
                  size: 46, color: AppColors.primary),
              SizedBox(height: 14),
              Text('还没有保存的场景',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              SizedBox(height: 7),
              Text(
                '创建一个专属情景后，可以从这里再次使用。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}
