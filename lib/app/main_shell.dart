import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../core/theme/app_theme.dart';
import '../features/chat/voice/voice_chat_providers.dart';
import 'voice_chat_providers.dart';

/// 四栏主壳：底部导航使用液态玻璃（玻璃只属于导航与控制层）。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  /// 测试钩子：纯 Dart 测试环境关闭玻璃渲染（着色器不可用时）。
  static bool disableGlass = false;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;
  int? _activeIndex;

  static const List<_TabSpec> _tabs = <_TabSpec>[
    _TabSpec(route: '/chat', icon: Icons.chat_bubble_outline, label: '聊一聊'),
    _TabSpec(
        route: '/scenario', icon: Icons.theater_comedy_outlined, label: '情景扮演'),
    _TabSpec(route: '/review', icon: Icons.book_outlined, label: '复习'),
    _TabSpec(route: '/profile', icon: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    if (websocketChatEnabled && index != _activeIndex) {
      _activeIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _activeIndex != index) return;
        final controller = ref.read(voiceChatProvider.notifier);
        if (index == 0) {
          unawaited(controller.activate(keepConnected: rtcChatEnabled));
        } else {
          unawaited(controller.deactivate());
          if (rtcChatEnabled) {
            ref.read(rtcVoiceSessionApiProvider).prefetchFreeChat();
          }
        }
      });
    }
    return Scaffold(
      // Keep the page painting behind the rounded glass dock. Without this,
      // Scaffold reserves an opaque strip and visually cuts the page off.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: MainShell.disableGlass
          ? _buildFallbackBar()
          : GlassTabBar.bottom(
              tabs: <GlassTab>[
                for (final _TabSpec tab in _tabs)
                  GlassTab(icon: Icon(tab.icon), label: tab.label),
              ],
              selectedIndex: navigationShell.currentIndex,
              onTabSelected: _selectTab,
              selectedIconColor: AppColors.primary,
              unselectedIconColor: AppColors.textSecondary,
              selectedLabelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
            ),
    );
  }

  Widget _buildFallbackBar() {
    return NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _selectTab,
      destinations: <Widget>[
        for (final _TabSpec tab in _tabs)
          NavigationDestination(
            icon: Icon(tab.icon),
            label: tab.label,
          ),
      ],
    );
  }

  void _selectTab(int index) {
    final int previousIndex = navigationShell.currentIndex;
    navigationShell.goBranch(
      index,
      initialLocation: index == previousIndex,
    );
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
