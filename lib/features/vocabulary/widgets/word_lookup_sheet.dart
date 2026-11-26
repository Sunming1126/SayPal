import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../models/vocab_models.dart';
import '../providers/vocabulary_providers.dart';

/// 点词释义弹层：显示释义并允许一键存入生词本。
/// [wordLookup] 返回 null 表示演示词典未收录。
Future<void> showWordLookupSheet(
  BuildContext context, {
  required String rawWord,
  required WidgetRef sheetRef,
  required WordLookupResult? Function(String word) wordLookup,
  required String source,
  bool alreadySaved = false,
}) {
  final String word = rawWord.toLowerCase().trim();
  final WordLookupResult? result = wordLookup(word);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) {
      if (result == null) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📖', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                '"$word"',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '演示词典暂时没有收录这个词，问问老师或家长吧！',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
      bool saved = alreadySaved;
      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        result.word,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (result.phonetic != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            result.phonetic!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    result.meaningZh,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (result.exampleEn != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.exampleEn!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (result.exampleZh != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                result.exampleZh!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: saved ? '已在生词本里啦 ✓' : '存入生词本',
                    icon: saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                    color: saved ? AppColors.success : AppColors.primary,
                    onPressed: saved
                        ? null
                        : () async {
                            await saveVocabWord(
                              sheetRef,
                              word: result.word,
                              meaningZh: result.meaningZh,
                              phonetic: result.phonetic,
                              exampleEn: result.exampleEn,
                              exampleZh: result.exampleZh,
                              source: source,
                            );
                            setState(() => saved = true);
                          },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
