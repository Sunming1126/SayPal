import 'dart:typed_data';

import 'conversation_context.dart';

/// Only this adapter boundary knows about sockets, microphone and playback.
abstract interface class VoiceTransport {
  Stream<Map<String, dynamic>> get events;
  Future<void> connect({required ConversationContext context});
  Future<void> send(Map<String, dynamic> command);

  /// Uploads S16/16 kHz/mono PCM without triggering an AI reply. The stream
  /// may begin with frames captured before the remote peer became ready.
  Future<void> uploadBufferedAudio(Stream<Uint8List> pcm);

  /// Explicitly submits the previously uploaded audio turn.
  Future<void> commitBufferedAudio();

  /// Cancels a queued/sent turn without tearing down an otherwise healthy
  /// connection.
  Future<void> cancelPendingTurn();
  Future<void> record(
      {required bool automaticEnd, required void Function() onEnd});

  /// Stops microphone capture without submitting or discarding this turn.
  /// Used by the recording time limit so the child can still tap Send.
  Future<void> stopRecording();

  /// Cancels the current recording and discards any uncommitted transcript.
  Future<void> cancelRecording();

  Future<void> endRecording();
  Future<void> play(Uint8List bytes);
  Future<void> stopPlayback();
  Future<void> setPlaybackMuted(bool muted);

  /// Temporarily silences capture/playback while keeping the live room alive.
  Future<void> setSessionActive(bool active);
  Future<void> close();
}

class VoiceFailure implements Exception {
  const VoiceFailure(this.message, {this.retryable = true});
  final String message;
  final bool retryable;
}
