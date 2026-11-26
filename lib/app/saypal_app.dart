import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/routing/app_router.dart';
import '../core/theme/app_theme.dart';
import 'auth_membership_coordinator.dart';

/// SayPal 根组件：主题 + GoRouter。
/// 液态玻璃控制层由 LiquidGlassWidgets.wrap 提供自适应降级。
class SayPalApp extends ConsumerWidget {
  const SayPalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 激活登录态 → 会员生命周期的协调器。
    ref.watch(authMembershipCoordinatorProvider);
    final GoRouter router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'SayPal 英语口语陪练',
      theme: buildSayPalTheme(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

/// 液态玻璃初始化包装（在 main 中使用；测试中直接使用 SayPalApp）。
class GlassWrappedApp extends StatelessWidget {
  const GlassWrappedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LiquidGlassWidgets.wrap(child: const SayPalApp());
  }
}
