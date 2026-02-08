# プロンプトライブラリ（Prompt Library）: サブスクリプション管理 iOSアプリ

- **対象スコープ**: AIDDで実装を生成エージェントに投げるための再利用プロンプト集。
- **作成日/更新日**: 2026-02-06
- **バージョン**: v0.1
- **ステータス**: Draft
- **想定読者**: iOS Dev
- **この資料の使い方**:
  - 各プロンプトの「入力」を埋めて実装依頼
  - 生成物が「チェックポイント」を満たすかレビューし、満たさない場合は差分修正を依頼

---

## Prompt P-001: SwiftDataモデル生成（Subscription/BillingEvent）

### 入力
- 参照: `03_detailed_design.md` の「3. データモデル設計」
- ターゲットOS: iOS 17+
- 命名規約（任意）: Entity接尾辞を付ける/付けない

### 出力
- `Data/Persistence/Models/Subscription.swift`
- `Data/Persistence/Models/BillingEvent.swift`

### チェックポイント
- 必須項目がモデルに存在する（name/amount/cycle/firstBillingDate 等）
- Relationshipが正しく張られ、削除時の挙動が想定通り（Cascade等）
- createdAt/updatedAtが更新される（最低限createdAtだけでも可）

---

## Prompt P-002: BillingEngine（日付計算/見込み生成）+ Unitテスト

### 入力
- 参照: `03_detailed_design.md` の「5. 主要アルゴリズム」
- 履歴生成範囲: pastMonths=6, futureMonths=12（暫定）
- タイムゾーン: Asia/Tokyo

### 出力
- `Domain/Services/BillingEngine.swift`
- `Tests/DomainTests/BillingEngineTests.swift`

### チェックポイント
- 月末（1/31→2月末）とうるう年（2/29）テストが通る
- cancelledの境界が仕様通り（含む/含まないを明文化）
- generateProjectedEventsが決定的（同入力で同結果）

---

## Prompt P-003: ExportService（JSON/CSV）+ Unitテスト

### 入力
- 参照: `03_detailed_design.md` の「6. エクスポート設計」
- JSON schemaVersion: 1.0
- CSVヘッダ: event_id, subscription_id, ...

### 出力
- `Domain/Models/ExportDTO.swift`（DTO/Encodable）
- `Domain/Services/ExportService.swift`
- `Common/Utils/CSVWriter.swift`
- `Tests/ExportTests/ExportServiceTests.swift`

### チェックポイント
- JSONに schemaVersion/exportedAt/subscriptions/billingEvents が含まれる
- CSVがカンマ/改行/ダブルクォートを適切にエスケープする
- ファイル名にタイムスタンプが入り、temporaryDirectoryに書き出せる

---

## Prompt P-004: CRUD画面（一覧/詳細/作成編集）

### 入力
- 参照: `01_requirements.md` FR-001/002/003/011/016
- UI: SwiftUI + MVVM
- フィルタ: status（active/paused/cancelled）

### 出力
- `Features/Subscriptions/SubscriptionListView.swift` + ViewModel
- `Features/Subscriptions/SubscriptionDetailView.swift` + ViewModel
- `Features/Subscriptions/SubscriptionEditView.swift` + ViewModel

### チェックポイント
- 必須未入力で保存できず、エラーメッセージが見える
- 一覧で検索/フィルタが動く
- 削除は確認ダイアログがある

---

## Prompt P-005: SummaryService + SummaryView

### 入力
- 参照: `01_requirements.md` FR-009
- 集計対象: 当月（見込み/確定）

### 出力
- `Domain/Services/SummaryService.swift`
- `Features/Summary/SummaryView.swift` + ViewModel
- `Tests/DomainTests/SummaryServiceTests.swift`

### チェックポイント
- 今月の範囲判定（タイムゾーン）がテストで固定されている
- confirmedとprojectedが別集計できる

---

## Prompt P-006: OSLogラッパ（PIIマスキング方針込み）

### 入力
- 参照: `02_definition.md` ロギング方針

### 出力
- `Common/Logging/Logger.swift`

### チェックポイント
- memo本文/サービス名をログに出さない
- export成功/失敗のログが残る

---

## Prompt P-007: UIテスト（最低限の導線）

### 入力
- シナリオ: サブスク作成 → 一覧に表示 → 詳細 → 編集 → 削除

### 出力
- `Tests/UITests/SubscriptionCRUDUITests.swift`

### チェックポイント
- 端末/シミュレータで安定して動く（flakyを減らすため要素IDを付ける）

---

## Assumptions（前提）
- 生成エージェントはリポジトリ内のファイルを読み書きできる

## Open Questions（未確定事項）
- App Store公開が前提の場合、プライバシーポリシー文面もプロンプト化するか

## Decisions（決定事項）
- 重要ロジックは必ずUnitテスト付きで生成する

## Out of Scope（やらないこと）
- iCloud同期/外部連携の実装プロンプト（v0.1では不要）
