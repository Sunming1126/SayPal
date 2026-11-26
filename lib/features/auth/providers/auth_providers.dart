import 'package:app_auth/app_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_auth_service.dart';

/// 登录服务。默认离线演示实现；在 main.dart 中
/// （配置了 `SAYPAL_ACCOUNT_API_BASE_URL` 时）override 为 FirebaseAuthService。
final authServiceProvider = Provider<AuthService>((ref) => DemoAuthService());

/// 登录态流。FirebaseAuth 会把已持久化的会话在启动时重放进这个流，
/// 因此无需额外的启动恢复逻辑。
final authSessionProvider = StreamProvider<AuthSession?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// 当前是否已登录。
final signedInProvider = Provider<bool>(
  (ref) => ref.watch(authSessionProvider).valueOrNull != null,
);
