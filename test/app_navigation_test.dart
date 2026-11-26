import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saypal/app/main_shell.dart';
import 'package:saypal/app/saypal_app.dart';
import 'package:saypal/app/voice_chat_providers.dart';
import 'package:saypal/features/chat/pages/chat_page.dart';
import 'package:saypal/features/chat/pages/voice_chat_page.dart';
import 'package:saypal/features/profile/pages/profile_page.dart';
import 'package:saypal/features/scenario/pages/roleplay_catalog_page.dart';
import 'package:saypal/features/vocabulary/pages/vocabulary_page.dart';

void main() {
  testWidgets('app opens each main tab', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() async {
      MainShell.disableGlass = false;
      await tester.binding.setSurfaceSize(null);
    });
    MainShell.disableGlass = true;

    final chatPage = websocketChatEnabled ? VoiceChatPage : ChatPage;
    await tester.pumpWidget(
      ProviderScope(overrides: voiceFeatureOverrides, child: const SayPalApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(chatPage), findsOneWidget);

    if (!websocketChatEnabled) {
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My name is Amy.'));
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump(const Duration(milliseconds: 2200));
      await tester.pumpAndSettle();
      expect(find.text('I like to play football.'), findsOneWidget);

      await tester.tap(find.text('结束'));
      await tester.pumpAndSettle();
      expect(find.textContaining('开口 1 次'), findsOneWidget);
      await tester.tap(find.text('好耶'));
      await tester.pumpAndSettle();
    }

    for (final (label, page) in [
      ('情景扮演', RoleplayCatalogPage),
      ('复习', ReviewPage),
      ('我的', ProfilePage),
      ('聊一聊', chatPage),
    ]) {
      final tab = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      await tester.tap(tab);
      await tester.pumpAndSettle();
      expect(find.byType(page), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
