import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/theme/app_theme.dart';
import '../features/chat/voice/voice_chat_providers.dart';
import 'voice_chat_providers.dart';

/// 四栏主壳：底部导航使用液态玻璃（玻璃只属于导航与控制层）。
class MainShell extends ConsumerWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// 测试钩子：纯 Dart 测试环境关闭玻璃渲染（着色器不可用时）。
  static bool disableGlass = false;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(route: '/chat', icon: Icons.chat_bubble_outline, label: '聊一聊'),
    _TabSpec(
        route: '/scenario', icon: Icons.theater_comedy_outlined, label: '情景扮演'),
    _TabSpec(route: '/review', icon: Icons.book_outlined, label: '复习'),
    _TabSpec(route: '/profile', icon: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // Keep the page painting behind the rounded glass dock. Without this,
      // Scaffold reserves an opaque strip and visually cuts the page off.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: disableGlass
          ? _buildFallbackBar(ref)
          : GlassTabBar.bottom(
              tabs: <GlassTab>[
                for (final _TabSpec tab in _tabs)
                  GlassTab(icon: Icon(tab.icon), label: tab.label),
              ],
              selectedIndex: navigationShell.currentIndex,
              onTabSelected: (int index) => unawaited(_selectTab(ref, index)),
              selectedIconColor: AppColors.primary,
              unselectedIconColor: AppColors.textSecondary,
              selectedLabelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
            ),
    );
  }

  Widget _buildFallbackBar(WidgetRef ref) {
    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (int index) => unawaited(_selectTab(ref, index)),
      destinations: <Widget>[
        for (final _TabSpec tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            label: tab.label,
          ),
      ],
    );
  }

  Future<void> _selectTab(WidgetRef ref, int index) async {
    final int previousIndex = navigationShell.currentIndex;
    final bool leavingChat =
        websocketChatEnabled && previousIndex == 0 && index != 0;
    navigationShell.goBranch(
      index,
      initialLocation: index == previousIndex,
    );
    if (leavingChat) {
      // Navigation stays instant while teardown starts immediately: stop the
      // AI task, leave RTC, then destroy the engine in the background turn.
      await ref.read(voiceChatProvider.notifier).deactivate();
    }
    if (websocketChatEnabled && index == 0) {
      await ref.read(voiceChatProvider.notifier).activate();
    }
  }
}

class _TabSpec {
  const _TabSpec({
    required this.route,
    required this.icon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final String label;
}
