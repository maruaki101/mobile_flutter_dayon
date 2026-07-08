import 'package:flutter_test/flutter_test.dart';
import 'package:sakestop/table_id.dart';

void main() {
  group('normalizedValidTableId', () {
    test('手入力値の前後の空白を除いて有効値を返す', () {
      expect(normalizedValidTableId('  Table_01-A  '), 'Table_01-A');
    });

    test('使用できない文字を含む値は無効', () {
      expect(normalizedValidTableId('Table/01'), isNull);
    });

    test('32文字を超える値は無効', () {
      expect(normalizedValidTableId(List.filled(33, 'A').join()), isNull);
    });
  });
}
