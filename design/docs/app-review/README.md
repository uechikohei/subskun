# App Store 審査対応 - 引き継ぎ・進捗管理

最終更新: 2026-02-23

## 現在のステータス

バトン: Apple側（返答待ち）

## 経緯サマリ

| 日付 | イベント |
|------|---------|
| 2026-02-15 | v1.0 審査提出 |
| 2026-02-18 | Rejected（iPad Air 11-inch M3 でレビュー）指摘: 2.3.3 iPadスクショ + 5.1.1(v) アカウント削除 |
| 2026-02-23 | 全調査完了。ソースコード側は問題なし。App Store Connect の Reply to App Review がエラーで使用不可。サポートフォームから苦情1通送信。devprograms@apple.com に包括的な苦情+法的通知を送信 |

## 指摘内容と対応状況

### 指摘1: Guideline 2.3.3 - iPadスクリーンショット

- 内容: 13インチiPadスクショがiPhoneデバイスフレームを表示している
- 原因: アプリは TARGETED_DEVICE_FAMILY=1（iPhone専用）だが、App Store ConnectがiPadスクショを必須としている
- ソースコード: 変更不要（既にiPhone専用設定済み）
- 問題: Appleのシステム矛盾（ASCがiPadスクショを要求 → レビューがiPhoneフレームを却下 → 解決不能）
- 対応: Appleに矛盾の解消を要求済み

### 指摘2: Guideline 5.1.1(v) - アカウント削除

- 内容: アカウント削除機能がないと指摘
- 事実: 完全実装済み。レビュワーが見落としている
- 場所: Settings → Account → Delete Account（赤ボタン）
- ソースコード:
  - UI: SubscriptionTracker/Features/Auth/AccountView.swift (44-100行)
  - ロジック: SubscriptionTracker/Features/Auth/AuthenticationStore.swift (128-159行)
  - テスト: SubscriptionTrackerTests/AccountDeletionTests.swift
- 対応: メールで操作手順を5ステップで明示済み

## 現在ブロックされている理由

1. Reply to App Review がエラーで送信できない
2. iPadスクショを削除した結果、再提出もブロックされている（「You must upload a screenshot for 13-inch iPad displays」）
3. アプリレコードの削除不可（Rejected状態 + bundle ID再利用不可）
4. サポートフォームから2通目送信不可（エラー）

## 送信済みメール

| 送信先 | 内容 | ファイル |
|--------|------|---------|
| Apple Developer Support（フォーム経由） | 審査プロセスの問題 + iPad矛盾 + アカウント削除 + ビジネス影響 | fastlane/apple_complaint.txt |
| devprograms@apple.com | 全問題の包括的苦情 + サポートシステム障害 + 法的措置通知 | fastlane/apple_final_complaint.txt |

## Apple から返答が来たらやること

### パターンA: iPadスクショ要件が免除される / 解決策が提示される

1. 指示に従ってApp Store Connectを設定
2. スクショはダウンロード済み: fastlane/screenshots/ja/ にiPhone用4枚あり
3. fastlane deploy で一括申請（ビルド→アップロード→メタデータ→審査提出）
4. Resolution Center（使える場合）でアカウント削除の手順も再度説明

### パターンB: iPadスクショを受け入れるよう変更される

1. iPadシミュレータでスクショを撮り直し
2. fastlane/screenshots/ja/ にiPad用スクショを追加
3. fastlane deploy で一括申請

### パターンC: Reply to App Review が修復される

1. 修復確認後、以下を返信:
   - アカウント削除の操作手順（5ステップ）
   - iPadスクショについての説明
2. 返信文のドラフトは fastlane/apple_complaint.txt の ISSUE 1, ISSUE 2 セクションを参照

### パターンD: 具体的な解決策が提示されない / たらい回し

1. App Review Board に正式 Appeal: https://developer.apple.com/contact/app-store/
2. Meet with Apple 予約（火曜/木曜）: App Review Appointment
3. 消費者庁への相談検討

### パターンE: 返答がない（1週間以上）

1. devprograms@apple.com にフォローアップメール送信
2. Apple Developer Forums に状況を投稿（他の開発者の目に触れさせる）
3. App Review Board Appeal を実行
4. 法的措置の準備開始

## fastlane セットアップ状況

セットアップ済み。APIキーも設定済み。

- fastlane/Fastfile: 全レーン定義済み
- fastlane/.env: APIキー設定済み（ASC_KEY_ID=XH827R65AU）
- fastlane/AuthKey_XH827R65AU.p8: APIキーファイル配置済み

使えるコマンド:

| コマンド | 用途 |
|---------|------|
| fastlane download_screenshots | ASCからスクショDL |
| fastlane download_metadata | ASCからメタデータDL |
| fastlane create_app | 新規アプリレコード作成 |
| fastlane build_auto | ビルド（Automatic Signing） |
| fastlane upload_binary | IPAアップロード |
| fastlane upload_metadata | メタデータ・スクショアップロード |
| fastlane submit_review | 審査提出 |
| fastlane deploy | 上記を一括実行 |

## ダウンロード済みアセット

- iPhone スクリーンショット（4枚）: fastlane/screenshots/ja/
  - 0_APP_IPHONE_65_0.png
  - 1_APP_IPHONE_65_1.png
  - 2_APP_IPHONE_65_2.png
  - 3_APP_IPHONE_65_3.png
- アプリアイコン（1024x1024）: SubscriptionTracker/App/Assets.xcassets/AppIcon.appiconset/iOS-subskun_icon.png

## 技術的な確認事項（確認済み）

- project.yml: TARGETED_DEVICE_FAMILY = '1'（iPhone専用）
- Info.plist: UIRequiresFullScreen = true, Portrait only
- iPad固有のUI実装: なし
- iPad判定コード: なし
- アカウント削除: 完全実装済み（Google/Apple両対応、データ全削除、テストあり）
- ソースコード変更: 不要
