import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/chat_persona.dart';

/// 选择器：挑选 AI 角色（音色 + 性格）。底部弹层，玻璃控制层样式由外层提供。
Future<void> showPersonaPickerSheet(
  BuildContext context, {
  required List<ChatPersona> personas,
  required ChatPersona selected,
  required ValueChanged<ChatPersona> onSelected,
}) {
  return showModalBottomSheet<void>(
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
            const SectionHeader(title: '选一个小老师'),
            for (final ChatPersona persona in personas)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ContentCard(
                  color: persona.id == selected.id
                      ? persona.color.withValues(alpha: 0.12)
                      : AppColors.surface,
                  onTap: () {
                    onSelected(persona);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Row(
                    children: [
                      Text(persona.emoji, style: const TextStyle(fontSize: 34)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  persona.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: persona.color.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    persona.voiceLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: persona.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              persona.personalityZh,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (persona.id == selected.id)
                        const Icon(Icons.check_circle,
                            color: AppColors.primary),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
