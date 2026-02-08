# トレーサビリティ（Traceability）: サブスクリプション管理 iOSアプリ

- **対象スコープ**: FR/NFR → 設計要素 → 実装タスク → テスト の対応表。
- **作成日/更新日**: 2026-02-06
- **バージョン**: v0.1
- **ステータス**: Draft
- **想定読者**: PM / iOS Dev / QA
- **この資料の使い方**:
  - 仕様漏れを検出する（「未対応」「要確認」を潰す）
  - 実装/テストの完了定義を揃える

---

## FRトレーサビリティ

| 要件ID | 要件概要 | 設計要素（02/03） | 実装タスク（04） | テスト（06/実装） | 状態 |
|---|---|---|---|---|---|
| FR-001 | サブスク作成 | Subscriptionモデル, EditView, UseCase | T2-1-1, T2-2-2, T2-3-2 | Unit(バリデーション), UI(保存) | Planned |
| FR-002 | 一覧/詳細閲覧 | ListView/DetailView, Repository | T2-3-1, T2-3-3 | UI(遷移/表示) | Planned |
| FR-003 | サブスク編集 | EditView, UseCase | T2-3-2, T2-2-2 | UI(編集保存) | Planned |
| FR-004 | 状態管理 | SubscriptionStatus, 状態遷移図 | T2-2-2, T2-3-2 | Unit(遷移), UI(表示) | Planned |
| FR-005 | 周期サポート | BillingCycleType, BillingEngine.addCycle | T3-1-1 | Unit(月次/年次/日数) | Planned |
| FR-006 | 見込み履歴生成 | BillingEngine.generateProjectedEvents, 履歴範囲設定 | T3-1-2, T3-2-1 | Unit(範囲生成) | Planned |
| FR-007 | 履歴確定 | BillingEvent.eventType, BillingEventUseCase | T3-2-2 | Unit+UI(確定) | Planned |
| FR-008 | 金額上書き | BillingEvent.isAmountOverridden, EditView | T3-2-3 | Unit(集計反映) | Planned |
| FR-009 | 集計 | SummaryService, SummaryView | T4-1-1, T4-2-1 | Unit(月次集計) | Planned |
| FR-010 | カテゴリ | Subscription.category, フィルタ/集計 | T2-3-2, (拡張) | Unit/UI(絞り込み) | Planned |
| FR-011 | 検索/フィルタ | Repositoryクエリ, ListView | T2-3-1, T2-2-1 | UI(検索/フィルタ) | Planned |
| FR-012 | JSONエクスポート | ExportService(JSON), ExportDTO, schemaVersion | T5-1-1 | Unit(JSONキー/日付) | Planned |
| FR-013 | CSVエクスポート | ExportService(CSV), CSVWriter | T5-1-2 | Unit(エスケープ) | Planned |
| FR-014 | エクスポート対象選択 | ExportView(UI), ExportService引数 | T5-1-3 | UI(対象選択) | Planned |
| FR-015 | 永続化 | SwiftData(Persistence) | T2-1-1, T2-1-2 | Unit(再起動相当) | Planned |
| FR-016 | 削除 | UseCase, 確認ダイアログ | T2-2-2, T2-3-3 | UI(削除) | Planned |
| FR-017 | 設定 | SettingsStore(UserDefaults), 設定画面 | (追加Task) | Unit(設定反映) | ToDo |

## NFRトレーサビリティ

| 要件ID | 要件概要 | 設計要素（02/03） | 実装タスク（04） | テスト/確認 | 状態 |
|---|---|---|---|---|---|
| NFR-001 | パフォーマンス | 履歴範囲制限、DBクエリ最適化 | T4-1-1, (最適化Task) | 大量データ手動確認 | Planned |
| NFR-002 | オフライン | バックエンドなし設計 | 全体 | ネットワークOFFで動作確認 | Planned |
| NFR-003 | データ保全 | SwiftDataトランザクション, エラーハンドリング | T2-2-2 | 保存失敗時の挙動確認 | Planned |
| NFR-004 | セキュリティ/プライバシー | PIIログ禁止、エクスポート注意文 | T6-2-1, T5-1-3 | ログレビュー/手動 | Planned |
| NFR-005 | 保守性 | Domain分離、テスト容易性 | 全体（特にE2/E3/E5） | Unitテストの存在 | Planned |
| NFR-006 | アクセシビリティ | Dynamic Type/VoiceOver | T6-1-1 | iOS設定で確認 | Planned |
| NFR-007 | コスト | バックエンドなし | 全体 | サーバー費ゼロ | Planned |
| NFR-008 | 監視/運用 | OSLog, クラッシュ監視 | T6-2-1 | クラッシュログ確認 | Planned |

---

## Assumptions（前提）
- タスクIDは `04_implementation_plan.md` のものを使用

## Open Questions（未確定事項）
- FR-017（設定）をどこまでv0.1で必須とするか（最低限の履歴範囲のみで良いか）

## Decisions（決定事項）
- 未対応（ToDo）はv0.1着手前にタスク化する

## Out of Scope（やらないこと）
- インポート機能のトレーサビリティはv0.2以降
