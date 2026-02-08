# 実装ステップ（Implementation Plan）: サブスクリプション管理 iOSアプリ

- **対象スコープ**: v0.1の実装計画（マイルストーン、Issue化できるタスク分解、テスト、リリース手順）。
- **作成日/更新日**: 2026-02-06
- **バージョン**: v0.1
- **ステータス**: Draft
- **想定読者**: iOS Dev / QA / 運用
- **この資料の使い方**:
  - このままGitHub Issues/JiraにEpic/Story/Taskとして切る
  - 各Taskの「受け入れ条件」「変更ファイル候補」「テスト」「完了定義」を満たしてDoneにする

---

## マイルストーン

### M1: プロジェクト基盤 + CRUD（最小動く）
- **目的**: サブスクを登録/編集/閲覧/削除できる。データが永続化される。

### M2: 請求エンジン + 履歴（見込み/確定）
- **目的**: 周期から請求イベントを生成し、表示・確定できる。

### M3: サマリ/検索/フィルタ
- **目的**: 月額合計などの把握ができ、一覧が使いやすい。

### M4: JSON/CSVエクスポート
- **目的**: 外部出力で可搬性を担保する。

### M5: 品質仕上げ + リリース準備
- **目的**: テスト/ログ/アクセシビリティ/ストア提出物を整える。

---

## 作業分解（Epic → Story → Task）

> 以降、Taskは「そのままIssue化」できる粒度を目指している。

### Epic E1: アプリ骨組み

#### Story S1-1: Xcodeプロジェクト作成と基本設定
- Task T1-1-1: Xcodeプロジェクト作成（SwiftUI + SwiftData）
  - 目的: 開発を開始できるベースを作る
  - 変更ファイル候補: `SubscriptionTrackerApp.swift`, `Project.pbxproj`, `Info.plist`
  - 受け入れ条件:
    - Given 新規プロジェクト
    - When iPhoneシミュレータで起動
    - Then TabViewが表示されクラッシュしない
  - テスト: 手動起動確認
  - 影響範囲: 全体
  - 完了定義: mainブランチでビルドが通る

- Task T1-1-2: 基本のLint/Format（任意）
  - 目的: 個人でもコード品質を維持
  - 変更ファイル候補: `.swiftformat`, `.swiftlint.yml`（導入するなら）
  - 受け入れ条件: CI/ローカルで整形できる
  - テスト: 手動
  - 完了定義: READMEに実行方法が書かれている

#### Story S1-2: 画面の骨組み（Tab/Navigation）
- Task T1-2-1: TabView（サマリ/一覧/設定）
  - 目的: 主要導線を固定
  - 変更ファイル候補: `Features/Summary/SummaryView.swift`, `Features/Subscriptions/SubscriptionListView.swift`, `Features/Settings/SettingsView.swift`
  - 受け入れ条件:
    - When タブを切り替える
    - Then 各タブが表示できる
  - テスト: 手動
  - 完了定義: 画面遷移が成立

---

### Epic E2: データモデル + CRUD

#### Story S2-1: SwiftDataモデル定義
- Task T2-1-1: Subscriptionモデル
  - 目的: サブスク定義を永続化
  - 変更ファイル候補: `Data/Persistence/Models/Subscription.swift`
  - 受け入れ条件:
    - When Subscriptionを作成して保存
    - Then 再起動後も取得できる（FR-015）
  - テスト: Unit（保存/取得）
  - 完了定義: モデルの基本CRUDが可能

- Task T2-1-2: BillingEventモデル
  - 目的: 請求履歴（見込み/確定）を永続化
  - 変更ファイル候補: `Data/Persistence/Models/BillingEvent.swift`
  - 受け入れ条件:
    - When BillingEventを保存
    - Then Subscriptionと関連付けて取得できる
  - テスト: Unit（Relationship）
  - 完了定義: Relationshipが破綻しない

#### Story S2-2: Repository/UseCase実装
- Task T2-2-1: SubscriptionRepository
  - 目的: ViewModelから永続化詳細を隠蔽
  - 変更ファイル候補: `Data/Repositories/SubscriptionRepository.swift`
  - 受け入れ条件: 一覧取得/検索/フィルタがRepository経由で可能
  - テスト: Unit
  - 完了定義: ViewModelからSwiftData直叩きを減らす

- Task T2-2-2: CRUD UseCase
  - 目的: バリデーション含むCRUDを集約
  - 変更ファイル候補: `Domain/Services/SubscriptionUseCase.swift`
  - 受け入れ条件: FR-001/003/016が満たせる
  - テスト: Unit（バリデーション）
  - 完了定義: エラーが型で扱える

#### Story S2-3: CRUD UI
- Task T2-3-1: 一覧（表示/検索/フィルタ）
  - 目的: FR-002/011
  - 変更ファイル候補: `Features/Subscriptions/SubscriptionListView.swift`, `...ViewModel.swift`
  - 受け入れ条件:
    - Given サブスクが複数
    - When 検索/フィルタ
    - Then 結果が反映
  - テスト: UIテスト（検索、フィルタ）
  - 完了定義: 主要導線が成立

- Task T2-3-2: 作成/編集フォーム
  - 目的: FR-001/003
  - 変更ファイル候補: `Features/Subscriptions/SubscriptionEditView.swift`
  - 受け入れ条件: 必須項目未入力で保存できない
  - テスト: Unit（バリデーション）、UIテスト（保存）
  - 完了定義: 入力が30秒で完了するUI（主観評価）

- Task T2-3-3: 詳細画面
  - 目的: FR-002
  - 変更ファイル候補: `Features/Subscriptions/SubscriptionDetailView.swift`
  - 受け入れ条件: 基本情報が表示され編集へ遷移できる
  - テスト: UI
  - 完了定義: 基本CRUDが一通り

---

### Epic E3: 請求エンジン + 履歴

#### Story S3-1: BillingEngine実装
- Task T3-1-1: addCycle（日付加算）
  - 目的: 月末/うるう年に強い日付計算
  - 変更ファイル候補: `Domain/Services/BillingEngine.swift`
  - 受け入れ条件: 月末ケースのテストが通る
  - テスト: Unit（多数）
  - 完了定義: 計算ルールがコードとテストに存在

- Task T3-1-2: generateProjectedEvents（範囲生成）
  - 目的: FR-006
  - 変更ファイル候補: `BillingEngine.swift`
  - 受け入れ条件: 過去N〜未来Mのイベントが生成される
  - テスト: Unit
  - 完了定義: 生成結果が決定的（再現性）

#### Story S3-2: 履歴UI（見込み/確定）
- Task T3-2-1: 履歴リスト表示
  - 目的: FR-006
  - 変更ファイル候補: `SubscriptionDetailView.swift`
  - 受け入れ条件: 見込み/確定が区別されて表示
  - テスト: UI
  - 完了定義: 主要操作が直感的

- Task T3-2-2: 確定操作
  - 目的: FR-007
  - 変更ファイル候補: `BillingEventUseCase.swift`, `...ViewModel.swift`
  - 受け入れ条件: 1イベントを確定できる
  - テスト: Unit + UI
  - 完了定義: エクスポートにも反映される

- Task T3-2-3: 金額上書き
  - 目的: FR-008
  - 変更ファイル候補: `BillingEventEditView.swift`
  - 受け入れ条件: その回だけ金額が変わる
  - テスト: Unit（計算/集計に反映）
  - 完了定義: isAmountOverriddenが正しく立つ

---

### Epic E4: サマリ/集計

#### Story S4-1: サマリ集計ロジック
- Task T4-1-1: 月次合計（見込み/確定）
  - 目的: FR-009
  - 変更ファイル候補: `Domain/Services/SummaryService.swift`
  - 受け入れ条件: 当月の合計が正しく計算される
  - テスト: Unit
  - 完了定義: 端末タイムゾーンに依存しないテスト

#### Story S4-2: サマリ画面
- Task T4-2-1: SummaryView実装
  - 目的: 使う動機の中心
  - 変更ファイル候補: `Features/Summary/SummaryView.swift`
  - 受け入れ条件: 今月合計と直近請求が見える
  - テスト: UI（表示確認）
  - 完了定義: 毎週見る画面として成立

---

### Epic E5: エクスポート

#### Story S5-1: ExportService（JSON/CSV）
- Task T5-1-1: JSONシリアライズ
  - 目的: FR-012
  - 変更ファイル候補: `Domain/Services/ExportService.swift`, `Domain/Models/ExportDTO.swift`
  - 受け入れ条件: schemaVersion付きでJSONが生成できる
  - テスト: Unit（JSONのキー存在、日付形式）
  - 完了定義: サンプルJSONをdocsに残す（任意）

- Task T5-1-2: CSV生成
  - 目的: FR-013
  - 変更ファイル候補: `ExportService.swift`, `Common/Utils/CSVWriter.swift`
  - 受け入れ条件: エスケープが正しい
  - テスト: Unit（カンマ/改行/クォート）
  - 完了定義: Excel/スプシで読める

- Task T5-1-3: ファイル生成とShare Sheet
  - 目的: iOSでの出力導線
  - 変更ファイル候補: `Features/Export/ExportView.swift`
  - 受け入れ条件: 共有シートが開きファイルが共有できる
  - テスト: 手動 + UI（可能なら）
  - 完了定義: 端末内のFilesへ保存できる

---

### Epic E6: 品質/リリース

#### Story S6-1: アクセシビリティ/UX
- Task T6-1-1: Dynamic Type / VoiceOver
  - 目的: NFR-006
  - 変更ファイル候補: 各View
  - 受け入れ条件: 文字サイズ最大でも崩れにくく読み上げできる
  - テスト: 手動
  - 完了定義: 主要画面を一通り確認

#### Story S6-2: 運用（クラッシュ/ログ）
- Task T6-2-1: OSLog整備
  - 目的: NFR-008
  - 変更ファイル候補: `Common/Logging/Logger.swift`
  - 受け入れ条件: 重要イベントがログに残る（PIIなし）
  - テスト: 手動
  - 完了定義: ログカテゴリがドキュメント化

#### Story S6-3: リリース準備
- Task T6-3-1: Privacy Policy/スクリーンショット/説明文（App Store公開する場合）
  - 目的: ストア要件
  - 変更ファイル候補: `docs/`（または外部）
  - 受け入れ条件: 提出に必要な素材が揃う
  - テスト: -
  - 完了定義: TestFlight配布可能

---

## ブランチ戦略・PRルール案
- ブランチ
  - `main`: 常にリリース可能
  - `feature/...`: 機能単位
- PRルール（個人でも推奨）
  - 1PRは200〜400行目安（レビュー/自分の見直ししやすさ）
  - テスト追加が必要な変更には必ずテストを同梱
  - スクリーンショット/短い動画でUI変更を残す

## 実装順序（依存関係）
1. M1: プロジェクト骨組み → Tab/Navigation
2. M2: SwiftDataモデル → Repository/UseCase → CRUD UI
3. M3: BillingEngine → 履歴UI → 確定/上書き
4. M4: サマリ集計 → SummaryView
5. M5: ExportService → ExportView
6. 仕上げ: テスト追加、アクセシビリティ、ログ

## データ移行とロールバック
- v0.1では大きな移行は想定しない。
- ただし将来スキーマ変更で壊れやすいので
  - JSONエクスポートをバックアップとして使えるようにする（インポートは将来）
  - DB破損時は「アプリ再インストール」で復旧不可になる点を注意喚起（将来対策）

## リリースチェックリスト（最小）
- [ ] 主要FR（CRUD/履歴/エクスポート）が受け入れ条件を満たす
- [ ] 月末/うるう年テストが通る
- [ ] エクスポートしたCSVをスプシで開ける
- [ ] クラッシュしない（基本操作）
- [ ] PIIがログに出ない
- [ ] App Storeに出す場合: プライバシーポリシー、説明文、スクショ

## 想定トラブルと切り戻し
- ビルドが壊れた: mainへrevert
- DBスキーマ破壊: 影響が大きい場合はバージョンを上げる前にバックアップ導線（エクスポート）を促す
- エクスポート不具合: 形式ごとにバージョン/スナップショットテストを追加

---

## Assumptions（前提）
- 個人開発で小さくリリースし、反復で改善する

## Open Questions（未確定事項）
- ストア公開の有無（公開するなら運用/素材が追加）

## Decisions（決定事項）
- v0.1はバックエンドなし

## Out of Scope（やらないこと）
- インポート
- 自動明細取り込み
