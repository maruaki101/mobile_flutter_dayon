# SakeStop

SakeStopは、飲食店のテーブルで商品を選び、注文内容と純アルコール量を確認できるFlutter注文アプリです。注文履歴はFirebase Realtime Databaseへ保存・同期されます。

現時点では利用者向け画面を実装しています。店舗スタッフ向けの受注・提供管理画面と利用者認証は未実装です。

## 主な機能

- 手入力によるテーブルID指定
- ニックネーム（未入力時は「ゲスト」）での利用開始
- ドリンク・フードのカート追加、数量変更、注文確定
- Firebase Realtime Databaseへの注文保存と注文履歴表示
- 飲料の容量・度数から算出した純アルコール量の表示
- 直近30分の純アルコール量が60g以上になった場合のペース通知
- 通知後30分間の再通知抑制
- 利用終了時のセッションクローズと画面リセット
- Firebase初期化失敗時の起動エラー表示

## 利用手順

1. テーブルIDを入力します。
2. 必要に応じてニックネームを入力し、「開始」を選びます。
3. 商品をカートへ追加します。
4. カートで商品と数量を確認し、「注文を確定」を選びます。
5. 注文履歴と純アルコール量を確認します。
6. 退店時に「利用を終了」を選びます。会計処理は店舗スタッフへ依頼します。

テーブルIDは1〜32文字の半角英数字・`_`・`-`を使用します（例：`T01`、`table_A-2`）。入力前後の空白は除去されます。

## 開発環境

- Flutter 3.35.7（stable）
- Dart 3.9.2
- Firebase Core 3.x
- Firebase Realtime Database 11.x
- UUID 4.x

## 対応状況

| プラットフォーム | 状況 | 備考 |
|---|---|---|
| Web | 動作・ビルド確認済み | 発表・提出時の主対象です。 |
| Windows | Firebase設定あり | テーブルIDを手入力して利用します。 |
| Android | 再設定が必要 | FirebaseのAndroidアプリ登録と設定再生成が必要です。 |
| iOS / macOS | 未設定・未検証 | FlutterFire CLIによるFirebase設定が必要です。 |
| Linux | 非対応 | 現在のFirebase設定では起動できません。 |

`lib/firebase_options.dart`のAndroid設定にはWeb用の`appId`が入っています。また、`android/app/google-services.json`はリポジトリに含まれていません。Android実機で使用する場合は、対象FirebaseプロジェクトへAndroidアプリを登録し、FlutterFire CLIで設定を再生成してください。

## セットアップと実行

依存パッケージを取得し、Web版を起動します。

```sh
flutter pub get
flutter run -d chrome
```

Web版をビルドする場合：

```sh
flutter build web
```

## 品質確認

```sh
flutter analyze
flutter test
```

2026年7月13日時点で、静的解析は問題なし、テストは11件すべて成功、Webビルド成功を確認しています。

主なテスト対象：

- テーブルIDの正規化と入力検証
- 純アルコール量の計算
- 直近30分の飲酒量集計
- 60g以上のペース通知判定
- 通知後30分のクールダウン
- テーブルID入力からニックネーム入力への画面遷移

## Firebaseデータ構造

```text
tables/{tableId}/sessions/{sessionId}
├─ closed_at
└─ members/{memberId}
   ├─ nickname
   ├─ created_at
   └─ orders/{orderId}
      ├─ drink_name
      ├─ pure_alcohol
      └─ timestamp
```

注文確定時は、カート内の各商品を数量分の履歴レコードに展開し、`orders`配下へ一括保存します。

## 関連資料

- `DOCS/SakeStop_画面仕様書.pptx`：画面・入力・処理・遷移・データ仕様
- `DOCS/SakeStop_仕様書.docx`：アプリ仕様書
- `DOCS/screens/`：各画面のスクリーンショット

## 制限事項と運用上の注意

- 利用者認証は未実装です。
- Firebase Realtime Database Rulesはリポジトリで管理していません。本番公開前に、必要最小限の読み書きだけを許可するRulesを設定してください。
- テーブルIDを知っている利用者による別テーブルへのアクセスを防ぐ仕組みは未実装です。
- 店舗スタッフ向けの受注・提供管理画面と会計機能は未実装です。
- 純アルコール量とペース通知は目安です。医療上の診断、飲酒可否、安全性の保証を行う機能ではありません。
