import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/scenario_models.dart';

/// 情景介绍页：进入前展示目标任务清单。
class ScenarioIntroPage extends StatelessWidget {
  const ScenarioIntroPage({required this.scenario, super.key});

  final LifeScenario scenario;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(scenario.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Text(
                  scenario.emoji,
                  style: const TextStyle(fontSize: 72),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                scenario.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                scenario.introZh,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              const SectionHeader(title: '你要完成的任务'),
              for (int i = 0; i < scenario.tasks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scenario.color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: scenario.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          scenario.tasks[i].titleZh,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              PrimaryActionButton(
                label: '开始演练',
                icon: Icons.play_arrow_rounded,
                color: scenario.color,
                onPressed: () =>
                    context.pushReplacement('/scenario/${scenario.id}/session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
