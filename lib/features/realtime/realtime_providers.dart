import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import 'demo/demo_tutor_repository.dart';
import 'domain/realtime_tutor_repository.dart';
import 'real/realtime_http_repository.dart';

/// 会话仓库工厂：根据运行时配置选择演示或真实实现。
final class ConfiguredRealtimeRepositoryFactory
    implements RealtimeTutorRepositoryFactory {
  @override
  bool get isRealAvailable => AppConfig.instance.isRealtimeConfigured;

  @override
  RealtimeTutorRepository create() {
    if (isRealAvailable) {
      return RealtimeHttpRepository();
    }
    return DemoRealtimeTutorRepository();
  }
}

final realtimeRepositoryFactoryProvider =
    Provider<RealtimeTutorRepositoryFactory>((ref) {
  return ConfiguredRealtimeRepositoryFactory();
});
