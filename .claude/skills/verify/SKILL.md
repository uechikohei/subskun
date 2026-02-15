---
name: verify
description: CI相当のチェック（XcodeGen再生成・ビルド・テスト）をローカルで全て実行
allowed-tools: Bash(xcodegen:*), Bash(xcodebuild:*)
---

CI相当のチェックをローカルで全て実行し、結果を報告してください。

実行順序:
1. XcodeGen でプロジェクト再生成
   ```
   cd /Users/kohei/Workspace/uechikohei/subskun
   xcodegen generate
   ```
2. ビルドチェック
   ```
   xcodebuild build -scheme SubsKun -destination 'platform=iOS Simulator,name=iPhone 16'
   ```
3. ユニットテスト実行
   ```
   xcodebuild test -scheme SubsKun -destination 'platform=iOS Simulator,name=iPhone 16'
   ```

結果サマリ:
- 各ステップの成否を一覧表示
- 全PASS → 「CI Ready」と表示
- 失敗あり → 失敗箇所とエラー内容を提示し、修正案を提案
