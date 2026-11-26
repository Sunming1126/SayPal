Uri? resolveServiceEndpoint(
  String baseUrl,
  String endpoint, {
  String? scheme,
}) {
  final base = Uri.tryParse(baseUrl);
  if (base == null ||
      !base.hasScheme ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    return null;
  }

  final baseSegments = base.pathSegments.where((segment) => segment.isNotEmpty);
  final endpointSegments =
      endpoint.split('/').where((segment) => segment.isNotEmpty);
  return base.replace(
    scheme: scheme ?? base.scheme,
    pathSegments: <String>[...baseSegments, ...endpointSegments],
  );
}
