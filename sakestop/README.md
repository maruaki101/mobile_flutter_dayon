# Sake Stop

Sake Stopは、飲食店のテーブルで商品を選び、注文内容と純アルコール量を確認できるFlutter注文アプリです。注文履歴はFirebase Realtime Databaseへ保存・同期されます。現時点では店舗スタッフ用の受注・提供管理画面は未実装です。

## 主な機能

- QRコードまたは手入力によるテーブルID指定
- ニックネーム（未入力時は「ゲスト」）での来店開始
- ドリンク・フードのカート注文と注文履歴表示
- 飲料の容量・度数から算出した純アルコール量の表示
- 直近30分の純アルコール量が20g以上になった場合のペース通知（再通知まで30分）
- 利用終了時のセッションクローズと画面リセット

## 利用手順

1. テーブルのQRコードを読み取るか、テーブルIDを入力します。
2. 必要に応じてニックネームを入力し、「開始」を選びます。
3. 商品をカートへ追加し、数量を確認して「注文を確定」を選びます。
4. 注文履歴と純アルコール量を確認し、退店時に「利用を終了」を選びます。お会計はスタッフへお声がけください。

QRコードの値は、1〜32文字の半角英数字・`_`・`-`だけを使用してください（例: `T01`, `table_A-2`）。前後の空白は除去されます。利用できない値のQRは採用されず、再スキャンできます。

## 対応状況

| プラットフォーム | Firebase | QRカメラ | 備考 |
|---|---|---|---|
| Web | 設定済み | 対応 | カメラ利用にはHTTPSまたはlocalhostが必要です。 |
| Android | 設定済み | 対応 | 公開前に下記のFirebase再生成注意を確認してください。 |
| Windows | 設定済み | 非対応 | テーブルIDを手入力します。 |
| iOS / macOS | 再設定が必要 | 未検証 | カメラ権限設定は含まれますが、まずFlutterFire CLIでFirebase設定を生成してください。 |
| Linux | 非対応 | 非対応 | 現在のFirebase設定では起動できません。 |

現在の`firebase_options.dart`ではAndroidの`appId`が`:web:`形式です。Android実機への公開前にFlutterFire CLIを実行し、対象FirebaseプロジェクトへAndroidアプリを登録したうえで設定を再生成してください。

## セットアップと実行

Flutter 3.29以降を用意してください（`mobile_scanner` 7.2.0を使用）。

```sh
flutter pub get
flutter run -d chrome
```

Androidでは接続済み端末またはエミュレーターを選択して`flutter run`を実行します。iOS/macOSなど未設定の環境を使う場合は、先にFlutterFire CLIで`lib/firebase_options.dart`を再生成してください。

品質確認:

```sh
flutter analyze
flutter test
```

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

注文確定時は、カート内の各品を1個につき1履歴レコードとして、`orders`配下へ一括更新します。

## 運用上の注意

- 現状は利用者認証を実装していません。本番運用前にFirebase Authenticationと、必要最小限の読み書きだけを許可するRealtime Database Rulesを設定してください。
- テーブルIDを知る利用者が別テーブルへアクセスできないよう、QR配布方法とRulesを含めて設計してください。
- 純アルコール量とペース通知は目安です。医療上の診断・判断や飲酒可否の判定を行う機能ではありません。
