import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

bool get hasNativeOralPractice =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

class OralPracticeEntryPage extends StatefulWidget {
  const OralPracticeEntryPage({super.key});

  @override
  State<OralPracticeEntryPage> createState() => _OralPracticeEntryPageState();
}

class _OralPracticeEntryPageState extends State<OralPracticeEntryPage> {
  static const _channel = MethodChannel('saypal/oral_practice');
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  Future<void> _open() async {
    setState(() => _failed = false);
    try {
      await _channel.invokeMethod<void>('open');
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/scenario');
      }
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('视频电话陪练')),
    body: Center(
      child: _failed
          ? FilledButton(onPressed: _open, child: const Text('暂时无法打开，重试'))
          : const CircularProgressIndicator(),
    ),
  );
}
