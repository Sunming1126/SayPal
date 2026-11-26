import 'package:flutter/material.dart';

class HoldToTalk extends StatefulWidget {
  const HoldToTalk({
    required this.enabled,
    required this.onStart,
    required this.onRelease,
    required this.onCancel,
    required this.child,
    super.key,
  });

  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onRelease;
  final VoidCallback onCancel;
  final Widget child;

  @override
  State<HoldToTalk> createState() => _HoldToTalkState();
}

class _HoldToTalkState extends State<HoldToTalk> {
  bool _holding = false;

  void _finish(VoidCallback callback) {
    if (!_holding) return;
    _holding = false;
    callback();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.enabled,
      child: Listener(
        onPointerCancel: (_) => _finish(widget.onCancel),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: widget.enabled
              ? (_) {
                  _holding = true;
                  widget.onStart();
                }
              : null,
          onLongPressEnd: (_) => _finish(widget.onRelease),
          child: widget.child,
        ),
      ),
    );
  }
}
