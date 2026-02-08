# テスト戦略（Test Strategy）: サブスクリプション管理 iOSアプリ

- **対象スコープ**: v0.1のテスト方針（テストレベル、重要シナリオ、品質観点、CI）。
- **作成日/更新日**: 2026-02-06
- **バージョン**: v0.1
- **ステータス**: Draft
- **想定読者**: iOS Dev / QA
- **この資料の使い方**:
  - `01_requirements.md` の受け入れ条件を「テストケース」に落とす
  - 特に請求日計算・エクスポートはバグが出やすいのでここを厚くする

---

## テストレベルと目的

### 1) ユニットテスト（XCTest）
- 対象: Domain/Services, CSV/JSONシリアライズ, バリデーション
- 目的: 端末/UIに依存しないロジックの正しさ担保

### 2) 統合テスト（軽量）
- 対象: SwiftData永続化 + Repository + UseCase
- 目的: モデル/関連/保存取得の整合性

### 3) UIテスト（XCUITest）
- 対象: CRUD導線, フィルタ/検索, エクスポート導線（共有シートは難しければ手動補完）
- 目的: 個人利用でも「迷わず使える」ことを担保

---

## 重要シナリオのテストケース（Given/When/Then）

### TS-001 月末請求の月次計算
- Given firstBillingDate=2025-01-31, cycle=monthly
- When 2回分の次回請求日を生成する
- Then 2025-02-28（うるう年なら29）と2025-03-31になる

### TS-002 うるう年の年次計算
- Given firstBillingDate=2024-02-29, cycle=yearly
- When 次回請求日を生成する
- Then 2025-02-28（またはポリシーに従う）になる

### TS-003 解約境界
- Given cancellationDate=2026-02-10
- When 2026-02-10以降の見込みを生成
- Then 2026-02-10まで（含む/含まないの方針）以外は生成されない

### TS-004 確定イベントの保護
- Given ある日付のBillingEventがconfirmed
- When Subscription定義を編集してprojectedを再生成
- Then confirmedイベントは残り、同日付にprojectedが重複しない

### TS-005 CSVエスケープ
- Given memo='hello, "world"\nnext'
- When CSV出力
- Then CSVがRFC4180相当にエスケープされ、スプシで正しく1セルに入る

### TS-006 JSON最低要件
- Given サブスク1件、イベント1件
- When JSON出力
- Then schemaVersion/exportedAt/subscriptions/billingEventsが存在し、日付形式が仕様通り

---

## パフォーマンステスト（最小）
- 目的: NFR-001
- データ: サブスク100件、イベント合計3000行を生成して表示
- 確認:
  - 一覧のスクロールがカクつかない
  - サマリ計算が体感遅くない（必要ならキャッシュ）
  - エクスポートがタイムアウトしない

---

## セキュリティ/プライバシーテスト（最小）
- ログにmemoや個人情報っぽい文字列が出ない
- エクスポート時にユーザーへ注意文が出る（任意）
- 端末ロックがある環境でデータがサンドボックスに保存される（iOS標準）

---

## テストデータ方針
- 基本はコードで生成（Factory）
- 日付計算テストはタイムゾーン固定（Asia/Tokyo）で再現性を上げる

---

## テスト環境/CI
- ローカル: XcodeでUnit/UIを実行
- CI（任意）: GitHub Actionsで `xcodebuild test` を回す

---

## Assumptions（前提）
- iOS 17+ をターゲット

## Open Questions（未確定事項）
- cancellationDateの「含む/含まない」境界の方針（設計で確定させる）

## Decisions（決定事項）
- 請求日計算とエクスポートはUnitテストを最優先する

## Out of Scope（やらないこと）
- 端末間同期のテスト（v0.1では不要）
