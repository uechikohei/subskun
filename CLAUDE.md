# CLAUDE.md

必ず日本語で回答すること。

## プロジェクト概要

subskun: iOS サブスクリプション管理アプリ

- フレームワーク: SwiftUI + SwiftData
- 言語: Swift 6.0
- 最低サポート: iOS 17.0
- ビルドツール: XcodeGen（`project.yml` → `.xcodeproj` 生成）
- 認証: Google Sign-In
- リポジトリ: `uechikohei/subskun`

## ソースコード構成

```
SubscriptionTracker/
  App/          # アプリエントリポイント、ルートビュー
  Common/       # 共通コンポーネント、Extensions、ユーティリティ
  Data/         # SwiftData モデル、設定
  Domain/       # ドメインモデル、ビジネスロジック
  Features/     # 機能別画面（Auth/Export/Settings/Subscriptions/Summary）
  Resources/    # ローカライズ、サービスカタログ
SubscriptionTrackerTests/  # ユニットテスト
```

## ビルド・テストコマンド

```bash
xcodegen generate                    # project.yml から .xcodeproj を再生成
xcodebuild build -scheme SubsKun -destination 'platform=iOS Simulator,name=iPhone 16'   # ビルド
xcodebuild test -scheme SubsKun -destination 'platform=iOS Simulator,name=iPhone 16'    # テスト実行
swift package resolve                # SPM 依存解決
```

## コーディング規約

### 命名規約

#### アプリケーション名

| 用途 | 表記 | 例 |
|------|------|-----|
| Display Name（UI表示・App Store） | サブスク君 | アプリ名、ロゴ、OGP |
| Machine Name（リポジトリ・パッケージ） | subskun | `uechikohei/subskun` |

#### ソースコード命名規則

Swift 標準の命名規則に従う（単体プロジェクトのためプレフィックス不要）:

| 対象 | 規則 | 例 |
|------|------|-----|
| 型・プロトコル | PascalCase | `SubscriptionListView`, `BillingEngine` |
| 変数・関数・プロパティ | camelCase | `billingCycle`, `calculateTotal()` |
| 定数 | camelCase | `let defaultCurrency` |
| ファイル名 | PascalCase | `SubscriptionDetailView.swift` |

### Gitコミットメッセージ

- プレフィックスは英語（Conventional Commits準拠）: `feat` / `fix` / `docs` / `refactor` / `test` / `chore` / `style` / `perf` / `ci`
- スコープ: `(ui)` / `(domain)` / `(data)` / `(test)` / `(config)`
- タイトル・詳細メッセージは日本語で記載
- 詳細（-m body）は箇条書きで変更内容を簡潔に記載
- Co-Authored-By行は付けない（著者はuechikoheiのみとする）

```
feat(ui): サブスクリプション編集画面にバリデーションを追加

- 必須項目の未入力チェックを実装
- エラーメッセージを日本語で表示
```

### ブランチ戦略

Git Flow を使用する

## 課題管理（GitHub Issues/Projects）

### 起票フォーマット（自動判定）

`/issue` コマンドで起票時、内容に応じてフォーマットを自動選択する:

| 判定条件 | フォーマット | ラベル |
|----------|-------------|--------|
| 既に発生した障害・バグ・技術調査 | **4F形式**（Fact/Find/Fix/Future） | `troubleshooting` |
| 未来の検討・新機能・設計・要件整理 | **STAR形式**（Situation/Task/Action/Result） | `planning` / `design` |
| 上記に当てはまらないナレッジ・メモ | **フリーフォーマット** | `knowledge` |

### 起票時の必須設定

- label: `troubleshooting` / `planning` / `design` / `knowledge`
- Priority: `P0`（本番障害）/ `P1`（開発に支障）/ `P2`（改善・バックログ）

### トラブルシューティング自動起票

Claude Codeの作業中にトラブルシューティングが発生し解消した場合、自動的に `/issue` を実行して4F形式で知見を記録する（起票前にユーザー承認を取る）。

### 4F参照の優先

動作テスト異常・エラーログ・障害調査の際は、`troubleshooting` / `knowledge` ラベル付きIssueを優先的に参照して過去事象を確認する。

## XcodeGen 運用ルール

- ファイル追加・削除時は `project.yml` を編集し `xcodegen generate` を実行すること
- `.xcodeproj` は `project.yml` から生成されるため、直接編集しない
- `project.yml` の変更後は必ず `xcodegen generate` で再生成する

## よくある落とし穴と回避策

- `GoogleService-Info.plist` は Git 追跡しない（Firebase設定は秘匿扱い）
- Xcode の Signing 設定は Automatic に設定（`CODE_SIGN_STYLE: Automatic`）、`DEVELOPMENT_TEAM: SW4S6FR5L9`
- SwiftData のマイグレーション: スキーマ変更時は `VersionedSchema` と `SchemaMigrationPlan` を使用すること
- `.env` ファイル・シークレット情報は絶対にコミットしない

## Plan Mode運用ルール

- 新機能実装は必ずPlan Mode（Shift+Tab x2）で設計を合意してから実装に入る
- 「コードを1行も書かせずに設計承認」の原則を守る
- 合意後にAuto-accept editsモードへ移行し、一撃実装する

## 実装完了後の品質チェック（必須）

コード実装が一段落したら、コミット前に必ず `/verify` を実行すること。
ユーザーから指示がなくても、以下の条件を満たしたら自発的に `/verify` を実行する:

- Plan Mode承認後の実装が完了したとき
- バグ修正やリファクタリングの作業が完了したとき
- ユーザーが「できた」「完了」「実装して」等の完了を示す発言をしたとき

`/verify` で失敗が見つかった場合は、修正してから再度 `/verify` を実行し、全PASSを確認してからユーザーに報告する。

## 自律動作の方針

### 許可を求めずに進めてよい操作

- ファイルの読み取り・編集・新規作成
- ビルド・テストの実行
- git add / git commit / git status / git diff / git log
- Plan承認後の実装作業全般

### 必ずユーザーに確認が必要な操作

- ファイルやディレクトリの削除（特に `rm -rf` 等の再帰削除）
- `git push`（リモートへの反映）
- `git reset --hard` / `git push --force` / `git rebase` 等の履歴改変操作
- バックアップなしでの不可逆な変更
- 本番環境・共有リソースへの影響がある操作
