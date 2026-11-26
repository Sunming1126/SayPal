import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saypal/features/realtime/voice/widgets/hold_to_talk.dart';

void main() {
  testWidgets('tap is ignored, hold and release sends, cancellation discards', (
    tester,
  ) async {
    final actions = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HoldToTalk(
            enabled: true,
            onStart: () => actions.add('start'),
            onRelease: () => actions.add('send'),
            onCancel: () => actions.add('cancel'),
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      ),
    );
    final button = find.byType(HoldToTalk);
    await tester.tap(button);
    expect(actions, isEmpty);

    final hold = await tester.startGesture(tester.getCenter(button));
    await tester.pump(kLongPressTimeout);
    expect(actions, ['start']);
    await hold.up();
    expect(actions, ['start', 'send']);

    final interrupted = await tester.startGesture(tester.getCenter(button));
    await tester.pump(kLongPressTimeout);
    await interrupted.cancel();
    expect(actions, ['start', 'send', 'start', 'cancel']);
  });
}
