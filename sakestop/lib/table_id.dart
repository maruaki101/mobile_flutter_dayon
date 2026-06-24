final RegExp _tableIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,32}$');

String normalizeTableId(String value) => value.trim();

String? tableIdValidationError(String value) {
  final normalized = normalizeTableId(value);
  if (normalized.isEmpty) {
    return 'テーブルIDを入力してください';
  }
  if (!_tableIdPattern.hasMatch(normalized)) {
    return 'テーブルIDは1〜32文字の英数字・_・-で入力してください';
  }
  return null;
}

String? normalizedValidTableId(String value) {
  if (tableIdValidationError(value) != null) return null;
  return normalizeTableId(value);
}
