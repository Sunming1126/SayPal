import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:volc_engine_rtc/codegen/android/index.dart' as rtc_android;
import 'package:volc_engine_rtc/codegen/pack/callback.dart' as rtc_callbacks;
import 'package:volc_engine_rtc/volc_engine_rtc.dart';

Future<void> setVolcRoomEventHandler(
  RTCRoom room,
  IRTCRoomEventHandler handler,
) async {
  if (Platform.isAndroid) {
    final nativeRoom = room.$instance as rtc_android.RTCRoom;
    await nativeRoom.setRTCRoomEventHandler(_AndroidRoomEventHandler(handler));
    return;
  }
  await room.setRTCRoomEventHandler(handler);
}

Future<int?> sendVolcUserBinaryMessage(
  RTCRoom room,
  String userId,
  Uint8List bytes,
) async {
  if (Platform.isAndroid) {
    final nativeRoom = room.$instance as rtc_android.RTCRoom;
    // The Android bridge can encode the Java long message ID as a string.
    final result = await nativeRoom.nativeCall<Object?>(
      'sendUserBinaryMessage',
      [userId, bytes, rtc_android.MessageConfig.RELIABLE_ORDERED.$value],
    );
    final messageId = switch (result) {
      int value => value,
      String value => int.tryParse(value),
      double value when value.isFinite => value.toInt(),
      _ => null,
    };
    if (messageId == null) {
      throw StateError('Unexpected RTC message ID type: ${result.runtimeType}');
    }
    return messageId;
  }
  return room.sendUserBinaryMessage(
    userId: userId,
    buffer: bytes,
    config: MessageConfig.reliable_ordered,
  );
}

// The Android SDK can emit (sender, bytes), but its generated Dart callback
// only accepts (messageId, sender, bytes). Preserve both native overloads.
class _AndroidRoomEventHandler
    extends rtc_callbacks.android_IRTCRoomEventHandler {
  _AndroidRoomEventHandler(IRTCRoomEventHandler handler) {
    updateInstance(handler);
  }

  @override
  FutureOr<void> onRoomBinaryMessageReceived(
    dynamic messageId,
    dynamic sender, [
    dynamic bytes,
  ]) {
    if (bytes == null && messageId is String && sender is List<int>) {
      return super.onRoomBinaryMessageReceived(0, messageId, sender);
    }
    return super.onRoomBinaryMessageReceived(messageId, sender, bytes);
  }
}
