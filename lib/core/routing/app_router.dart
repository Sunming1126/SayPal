import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/main_shell.dart';
import '../../app/voice_chat_providers.dart';
import '../../features/auth/pages/auth_page.dart';
import '../../features/chat/pages/voice_chat_page.dart';
import '../../features/chat/pages/chat_page.dart';
import '../../features/learning/pages/lesson_cover_page.dart';
import '../../features/learning/pages/lesson_play_page.dart';
import '../../features/learning/pages/learning_map_page.dart';
import '../../features/learning/pages/theme_course_page.dart';
import '../../features/membership/pages/membership_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/scenario/data/seed_scenarios.dart';
import '../../features/scenario/models/scenario_models.dart';
import '../../features/scenario/pages/scenario_intro_page.dart';
import '../../features/scenario/pages/scenario_session_page.dart';
import '../../features/scenario/pages/custom_roleplay_page.dart';
import '../../features/scenario/pages/roleplay_catalog_page.dart';
import '../../features/scenario/pages/roleplay_collection_page.dart';
import '../../features/scenario/pages/roleplay_session_page.dart';
import '../../features/scenario/pages/video_roleplay_page.dart';
import '../../features/statistics/pages/statistics_page.dart';
import '../../features/vocabulary/pages/vocabulary_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// 应用路由。四个底部导航分支使用 StatefulNavigationShell 保持各页状态；
/// 二级页（课程/情景会话/生词本/统计）在根导航器上全屏打开。
GoRouter buildAppRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/chat',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        builder: (BuildContext context, GoRouterState state,
                StatefulNavigationShell navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/chat',
                builder: (BuildContext context, GoRouterState state) =>
                    websocketChatEnabled
                        ? const VoiceChatPage()
                        : const ChatPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/scenario',
                builder: (BuildContext context, GoRouterState state) =>
                    const RoleplayCatalogPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/review',
                builder: (BuildContext context, GoRouterState state) =>
                    const ReviewPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/profile',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      // —— 二级页面（根导航器全屏） ——
      GoRoute(
        path: '/learning',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const LearningMapPage(),
      ),
      GoRoute(
        path: '/scenario/video-practice',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const VideoRoleplayCatalogPage(),
        routes: [
          GoRoute(
            path: ':lessonId',
            builder: (context, state) => VideoRoleplayLessonPage(
              key: state.pageKey,
              lessonId: state.pathParameters['lessonId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/scenario/roleplay',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) => '/scenario',
      ),
      GoRoute(
        path: '/scenario/roleplay/custom',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CustomRoleplayPage(),
      ),
      GoRoute(
        path: '/scenario/roleplay/custom/saved',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const CustomRoleplayPage(showSaved: true),
      ),
      GoRoute(
        path: '/scenario/roleplay/recommended',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const RoleplayCollectionPage.recommended(),
      ),
      GoRoute(
        path: '/scenario/roleplay/category/:categoryId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            RoleplayCollectionPage.category(
          categoryId: state.pathParameters['categoryId']!,
        ),
      ),
      GoRoute(
        path: '/scenario/roleplay/:scenarioId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            RoleplaySessionPage(
          scenarioId: state.pathParameters['scenarioId']!,
        ),
      ),
      GoRoute(
        path: '/scenario/tutor',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) =>
            '/learning?tab=theme',
      ),
      GoRoute(
        path: '/scenario/tutor/:courseId/practice/:stage',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) =>
            '/learning/theme/${state.pathParameters['courseId']}'
            '/practice/${state.pathParameters['stage']}',
      ),
      GoRoute(
        path: '/scenario/tutor/:courseId',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) =>
            '/learning/theme/${state.pathParameters['courseId']}',
      ),
      GoRoute(
        path: '/learning/lesson/:lessonId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            LessonCoverPage(lessonId: state.pathParameters['lessonId']!),
        routes: <RouteBase>[
          GoRoute(
            path: 'play',
            parentNavigatorKey: rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                LessonPlayPage(lessonId: state.pathParameters['lessonId']!),
          ),
        ],
      ),
      GoRoute(
        path: '/scenario/:scenarioId',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) {
          final LifeScenario? scenario =
              findScenario(state.pathParameters['scenarioId'] ?? '');
          if (scenario == null) {
            return '/scenario';
          }
          return null;
        },
        builder: (BuildContext context, GoRouterState state) =>
            ScenarioIntroPage(
          scenario: findScenario(state.pathParameters['scenarioId']!)!,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'session',
            parentNavigatorKey: rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                ScenarioSessionPage(
              scenarioId: state.pathParameters['scenarioId']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/learning/theme/:courseId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) => ThemeCoursePage(
          courseId: state.pathParameters['courseId']!,
        ),
        routes: <RouteBase>[
          GoRoute(
            path: 'practice/:stage',
            parentNavigatorKey: rootNavigatorKey,
            builder: (BuildContext context, GoRouterState state) =>
                ThemeCoursePracticePage(
              courseId: state.pathParameters['courseId']!,
              stage: state.pathParameters['stage']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/vocabulary',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const VocabularyPage(),
      ),
      GoRoute(
        path: '/profile/vocabulary',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (BuildContext context, GoRouterState state) => '/vocabulary',
      ),
      GoRoute(
        path: '/profile/statistics',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const StatisticsPage(),
      ),
      // —— 登录与会员（不强制登录；会员详情页可浏览，购买前才要求登录） ——
      GoRoute(
        path: '/auth',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            const MaterialPage<void>(
          fullscreenDialog: true,
          child: AuthPage(),
        ),
      ),
      GoRoute(
        path: '/profile/membership',
        parentNavigatorKey: rootNavigatorKey,
        builder: (BuildContext context, GoRouterState state) =>
            const MembershipPage(),
      ),
    ],
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return buildAppRouter(ref);
});
