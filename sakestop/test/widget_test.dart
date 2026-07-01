import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakestop/main.dart';

void main() {
  testWidgets('テーブルID入力からニックネーム入力へ進む', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: QRScanScreen(onScanned: (tableId, nickname) async => true),
      ),
    );

    expect(find.text('テーブルIDを入力してください'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  T01  ');
    await tester.tap(find.text('このテーブルで進む'));
    await tester.pump();

    expect(find.text('ニックネームを入力してください'), findsOneWidget);
    final nicknameField = tester.widget<TextField>(find.byType(TextField));
    expect(nicknameField.decoration?.labelText, '呼び名（任意）');
  });
}
