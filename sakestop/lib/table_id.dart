// テーブルIDの正規表現: 半角英数字、_、- を許可し、最大32文字まで
final RegExp _tableIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,32}$');

// 入力値の前後の空白を削除する
String normalizeTableId(String value) => value.trim();

// テーブルIDとして有効かどうか検証し、エラーメッセージを返す
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

// 有効なテーブルIDなら正規化した文字列を返す
String? normalizedValidTableId(String value) {
  if (tableIdValidationError(value) != null) return null;
  return normalizeTableId(value);
}
