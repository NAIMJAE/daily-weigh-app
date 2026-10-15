String? canonicalStoragePath(String? value, String bucket) {
  if (value == null || value.trim().isEmpty) return null;
  final trimmed = value.trim();
  for (final marker in ['/object/sign/$bucket/', '/object/public/$bucket/']) {
    final index = trimmed.indexOf(marker);
    if (index < 0) continue;
    final rest = trimmed.substring(index + marker.length).split('?').first;
    if (rest.isEmpty) return null;
    return Uri.decodeFull(rest);
  }
  return trimmed;
}
