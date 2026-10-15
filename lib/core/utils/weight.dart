double? roundWeight(String raw) {
  final value = double.tryParse(raw.trim());
  if (value == null) return null;
  return (value * 10).round() / 10;
}
