import 'package:flutter/material.dart';

class RoleplayArtwork extends StatelessWidget {
  const RoleplayArtwork({
    required this.asset,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    super.key,
  });

  final String asset;
  final Color fallback;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, __, ___) => ColoredBox(color: fallback),
      );
}

Color roleplayHexColor(String value) {
  final String hex = value.replaceFirst('#', '');
  return Color(int.parse('FF$hex', radix: 16));
}
