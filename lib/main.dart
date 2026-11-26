import 'dart:io';

import 'package:app_auth/app_auth.dart';
import 'package:app_membership/app_membership.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/saypal_app.dart';
import 'app/profile_overview_repository.dart';
import 'app/voice_chat_providers.dart';
import 'core/config/app_config.dart';
import 'core/services/local_store.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/membership/data/secure_membership_cache.dart';
import 'features/membership/models/membership_access.dart';
import 'features/membership/providers/membership_providers.dart';
import 'features/profile/providers/profile_providers.dart';
import 'features/scenario/data/roleplay_favorites_repository.dart';
import 'features/statistics/providers/statistics_providers.dart';
import 'features/vocabulary/providers/vocabulary_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 预热液态玻璃着色器（仅导航与控制层使用玻璃）。
  await LiquidGlassWidgets.initialize();

  // 本机持久化：档案 / 学习记录 / 生词本 / 解锁进度。
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final LocalStore localStore = SharedPreferencesLocalStore(prefs);
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  const String compiledChatToken =
      String.fromEnvironment('SAYPAL_CHAT_TOKEN');
  const String debugTokenStorageKey = 'saypal.debug.chat_token';
  String runtimeChatToken = compiledChatToken;
  if (kDebugMode) {
    final launchToken = Platform.environment['SAYPAL_CHAT_TOKEN']?.trim();
    if (launchToken != null && launchToken.isNotEmpty) {
      // Xcode can inject a test credential at launch without embedding it.
      runtimeChatToken = launchToken;
    } else if (compiledChatToken.isNotEmpty) {
      await secureStorage.write(
        key: debugTokenStorageKey,
        value: compiledChatToken,
      );
    } else {
      runtimeChatToken =
          await secureStorage.read(key: debugTokenStorageKey) ?? '';
    }
  }

  final List<Override> overrides = <Override>[
    localStoreProvider.overrideWithValue(localStore),
    profileOverviewRepositoryProvider.overrideWith(
      (ref) => AppProfileOverviewRepository(
        ref.watch(learningRecordRepositoryProvider),
        ref.watch(vocabularyRepositoryProvider),
        RoleplayFavoritesRepository(ref.watch(localStoreProvider)),
      ),
    ),
    ...voiceFeatureOverrides,
    if (runtimeChatToken.isNotEmpty)
      voiceChatTokenProvider.overrideWithValue(runtimeChatToken),
  ];

  // 登录与会员链路：只在配置了账号服务地址时启用；
  // 否则保持默认的离线演示实现（DemoAuthService / DemoMembershipService）。
  final AppConfig config = AppConfig.instance;
  if (Platform.isIOS && config.isAccountConfigured) {
    // iOS 从 Runner Target 内的 GoogleService-Info.plist 读取默认 Firebase App。
    // 其他平台接入时，再用 FlutterFire CLI 生成对应平台的 firebase_options.dart。
    await Firebase.initializeApp();

    final Uri accountApi = Uri.parse(config.accountApiBaseUrl);
    final FirebaseAuthService authService = FirebaseAuthService(
      fallbackDisplayName: 'SayPal 用户',
      emailOtpClient: HttpEmailOtpClient(apiBaseUri: accountApi),
      accountClient: HttpAccountClient(apiBaseUri: accountApi),
    );
    final AppleMembershipService membershipService = AppleMembershipService(
      api: HttpMembershipApi(apiBaseUri: accountApi),
      cache: SecureMembershipCache(secureStorage),
      tokenProvider: ({bool forceRefresh = false}) async {
        try {
          // 10 秒超时：避免弱网/黑网络环境下启动卡死（同 Lighter 的处理）。
          return await authService
              .getIdToken(forceRefresh: forceRefresh)
              .timeout(const Duration(seconds: 10));
        } on AuthFailure catch (error) {
          if (error.code == 'not-authenticated') return null;
          rethrow;
        }
      },
      productIds: saypalMembershipProductIds,
      logger: (String message) => debugPrint('[Membership] $message'),
    );
    overrides.addAll(<Override>[
      authServiceProvider.overrideWithValue(authService),
      membershipServiceProvider.overrideWithValue(membershipService),
    ]);
  }

  runApp(
    ProviderScope(
      overrides: overrides,
      child: LiquidGlassWidgets.wrap(child: const SayPalApp()),
    ),
  );
}
