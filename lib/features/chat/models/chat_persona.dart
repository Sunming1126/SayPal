import 'package:flutter/material.dart';

/// AI 对话角色：音色 + 性格 + 演示脚本。
class ChatPersona {
  const ChatPersona({
    required this.id,
    required this.name,
    required this.emoji,
    required this.voiceLabel,
    required this.personalityZh,
    required this.color,
    required this.demoScriptEn,
  });

  final String id;
  final String name;
  final String emoji;

  /// 音色名称（真实链路对应 TTS voice_type；演示链路仅作展示）。
  final String voiceLabel;

  /// 性格描述（中文，给孩子看）。
  final String personalityZh;
  final Color color;

  /// 演示脚本：AI 依次说的话，每轮给出可选示范回答。
  final List<ChatDemoTurn> demoScriptEn;
}

/// 演示脚本的一轮。
class ChatDemoTurn {
  const ChatDemoTurn({required this.aiText, this.aiTextZh, required this.suggestions});

  final String aiText;
  final String? aiTextZh;
  final List<String> suggestions;
}
