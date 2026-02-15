# アカウント削除機能

| 項目 | 内容 |
|------|------|
| 作成日 | 2026-02-15 |
| ステータス | Draft |
| 著者 | Claude Code |
| 関連Issue | #6 |

## 1. 要件サマリ

### 背景

App Store Guideline 5.1.1(v) により、アカウント作成をサポートするアプリはアカウント削除機能の提供が必須。現在はログアウト機能のみでアカウント削除がないためリジェクトされている。

### ユーザーストーリー

As a サブスク君ユーザー, I want アカウントと全データを削除できる機能, so that 個人データを完全に消去して初期状態に戻せる。

### スコープ

- **やること**:
  - AccountView に「アカウントを削除」ボタンを追加
  - 確認ダイアログ（誤操作防止）の表示
  - 全データ削除（SwiftData + UserDefaults + 認証トークン）
  - ローカライズ文字列の追加（ja/en）
- **やらないこと**:
  - サーバーサイドのデータ削除（サーバーなし）
  - 部分削除（選択式の削除）
  - 削除猶予期間の実装

### 制約条件

- Google Sign-In SDK の `disconnect()` でトークン取り消し
- SwiftData の cascade 削除（Subscription → BillingEvent）
- 削除後は `AppFlowView` が自動的にログイン画面に遷移（`currentUser == nil` 検知）

## 2. 技術設計

### アーキテクチャ概要

```
AccountView
  └── 「アカウントを削除」ボタン押下
       └── confirmationDialog 表示
            └── 確認 → AuthenticationStore.deleteAccount(modelContext:settings:) 呼び出し
                 ├── 1. Google disconnect() / Apple ローカルキャッシュ削除
                 ├── 2. SwiftData 全レコード削除（Subscription → BillingEvent cascade）
                 ├── 3. UserDefaults 全キー削除（auth + settings + cache）
                 ├── 4. AppSettings のメモリ上の値をリセット
                 └── 5. currentUser = nil → AppFlowView が AuthGateView に自動遷移
```

### 変更対象ファイル

| ファイル | 変更内容 |
|----------|----------|
| `SubscriptionTracker/Features/Auth/AuthenticationStore.swift` | `deleteAccount(modelContext:settings:)` メソッド追加 |
| `SubscriptionTracker/Features/Auth/AccountView.swift` | 削除ボタン + confirmationDialog 追加、`@Environment(\.modelContext)` 追加 |
| `SubscriptionTracker/Resources/ja.lproj/Localizable.strings` | アカウント削除関連キー追加（3キー） |
| `SubscriptionTracker/Resources/en.lproj/Localizable.strings` | アカウント削除関連キー追加（3キー） |

新規ファイル作成: なし

### データモデル

変更なし。既存の `Subscription`（cascade で `BillingEvent` 自動削除）をそのまま利用。

### インターフェース設計

#### AuthenticationStore に追加するメソッド

```swift
func deleteAccount(modelContext: ModelContext, settings: AppSettings) {
    // 1. 認証プロバイダーのトークン取り消し
    // 2. SwiftData 全レコード削除
    // 3. UserDefaults 全キー削除
    // 4. AppSettings メモリリセット
    // 5. サインアウト状態に遷移
}
```

#### AccountView の変更

```swift
// 追加するプロパティ
@Environment(\.modelContext) private var modelContext
@EnvironmentObject private var settings: AppSettings
@State private var isDeleteAccountDialogPresented = false

// 追加するUI要素
Section {
    Button(role: .destructive) { ... }  // 「アカウントを削除」
}
.confirmationDialog(...)  // 削除確認ダイアログ
```

### 主要ロジック

#### 削除対象データ一覧

**SwiftData:**
- `Subscription` 全レコード（`BillingEvent` は cascade で自動削除）

**UserDefaults（認証系）:**
- `auth.currentUser` — 現在のユーザー情報
- `auth.appleIdentityCache` — Apple ID キャッシュ
- `auth.emailRegistry` — メールアドレス登録履歴

**UserDefaults（設定系）:**
- `settings.defaultCurrency`
- `settings.historyPastMonths`
- `settings.historyFutureMonths`
- `settings.includePausedInSummary`
- `settings.themeMode`
- `settings.themeColor`
- `settings.notifyBeforeBilling`

**UserDefaults（キャッシュ系）:**
- `exchange_rate.snapshot.v1` — 為替レートキャッシュ
- `service_catalog.payload.v1` — サービスカタログキャッシュ

#### 削除フロー

1. Google プロバイダーの場合: `GIDSignIn.sharedInstance.disconnect()` でトークン取り消し + `signOut()`
2. Apple プロバイダーの場合: ローカルキャッシュのみ削除（サーバーレスのため）
3. `modelContext.delete(model: Subscription.self)` で全 Subscription 削除（BillingEvent は cascade）
4. `modelContext.save()` で確定
5. UserDefaults の全キーを `removeObject(forKey:)` で削除
6. `AppSettings` のメモリ上の値をデフォルト値にリセット
7. `applySignedInUser(nil)` で `currentUser = nil` に設定 → AppFlowView が自動遷移

### ローカライズ文字列

**日本語（ja）:**
```
"auth.account.delete_account" = "アカウントを削除";
"auth.account.delete_account.confirm_title" = "アカウントを削除しますか？";
"auth.account.delete_account.confirm_message" = "すべてのサブスクリプションデータと設定が完全に削除されます。この操作は取り消せません。";
```

**英語（en）:**
```
"auth.account.delete_account" = "Delete Account";
"auth.account.delete_account.confirm_title" = "Delete your account?";
"auth.account.delete_account.confirm_message" = "All subscription data and settings will be permanently deleted. This action cannot be undone.";
```

## 3. 実現可能性評価

| 調査項目 | 結果 | 実現可能性 |
|----------|------|-----------|
| SwiftData一括削除 | `modelContext.delete(model:)` で全件削除可能。cascade 設定済み | 高 |
| Google disconnect | `GIDSignIn.sharedInstance.disconnect()` — SDK標準API | 高 |
| UserDefaults全クリア | `removeObject(forKey:)` で個別削除。既存パターンあり | 高 |
| UI実装 | 既存の `confirmationDialog` パターンをそのまま踏襲 | 高 |
| 画面遷移 | `currentUser == nil` で AppFlowView が自動遷移。追加実装不要 | 高 |

### 総合評価

**高** — 全て既存パターンの踏襲で実現可能。新規ライブラリ不要、アーキテクチャ変更なし。

## 4. リスクと対策

| リスク | 影響度 | 発生確率 | 対策 |
|--------|--------|----------|------|
| SwiftData削除失敗時にUIが中途半端な状態になる | 中 | 低 | エラーハンドリングでログ出力。削除失敗時は認証状態を維持 |
| Google disconnect のネットワークエラー | 低 | 低 | disconnect は非同期だがローカル削除は継続。次回Sign-In時にGoogleが再認証を要求するため問題なし |
| ユーザーの誤操作による意図しない削除 | 高 | 低 | confirmationDialog で明確な警告メッセージを表示 |

## 5. テスト計画

### ユニットテスト

| テストケース | Given | When | Then |
|-------------|-------|------|------|
| Googleアカウント削除 | Googleでサインイン済み | deleteAccount() 呼び出し | currentUser == nil、UserDefaults全キー削除済み |
| Appleアカウント削除 | Appleでサインイン済み | deleteAccount() 呼び出し | currentUser == nil、appleIdentityCache削除済み |
| 未ログイン時 | currentUser == nil | deleteAccount() 呼び出し | 何も起きない（クラッシュしない） |

### 手動確認項目

- [ ] Googleアカウントで削除 → ログイン画面に遷移すること
- [ ] Appleアカウントで削除 → ログイン画面に遷移すること
- [ ] 削除後に再ログイン → サブスクデータが空であること
- [ ] 削除後に再ログイン → 設定がデフォルト値に戻っていること
- [ ] 確認ダイアログで「キャンセル」→ 何も削除されないこと
- [ ] 日本語/英語でダイアログの文言が正しく表示されること

## 6. 実装ステップ

| # | タスク | 規模 | 依存 |
|---|--------|------|------|
| 1 | ローカライズ文字列追加（ja/en） | S | - |
| 2 | AuthenticationStore に `deleteAccount(modelContext:settings:)` メソッド追加 | M | - |
| 3 | AppSettings に `resetToDefaults()` メソッド追加 | S | - |
| 4 | AccountView に削除ボタン + confirmationDialog 追加 | S | #1, #2, #3 |
| 5 | ユニットテスト追加 | M | #2, #3 |

## 7. 参考資料

- [Apple: Offering Account Deletion in Your App](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [App Store Review Guideline 5.1.1(v)](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)
- [Google Sign-In iOS SDK - disconnect()](https://developers.google.com/identity/sign-in/ios/disconnect)
- Issue #6: fix(auth): App Store Guideline 5.1.1(v) アカウント削除機能の実装
