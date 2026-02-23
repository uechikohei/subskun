# Session Context

**Session ID:** 92d22688-02ce-4d25-bc78-82a7b33fbece

**Commit Message:** API 機は持ってないですね。API 機が必要なら作成の仕方の手順を書いておいてください。既存アプリのレコードを削除するのも無理っていうのは分か

## Prompt

API 機は持ってないですね。API 機が必要なら作成の仕方の手順を書いておいてください。既存アプリのレコードを削除するのも無理っていうのは分かりました。あとなんですけど、サブスクンってスクリーンショットを作ってるんですよね。それって既存の申請でアップロードしてローカルのファイルから消してる状態なんですよ、多分。なんでそれに関してはダウンロードして使い回したいんですけど、それも可能ですか?

## Summary

セットアップ完了です。以下が全体像です。

---

## 作成したファイル

- `fastlane/Fastfile` — 全レーンの定義
- `fastlane/Appfile` — アプリ識別情報
- `fastlane/.env.example` — API キー設定のテンプレート
- `.gitignore` — fastlane関連の秘匿ファイルを追加

## 使えるレーン一覧

| コマンド | やること |
|---------|---------|
| `fastlane download_screenshots` | 既存アプリからスクショをダウンロード |
| `fastlane fix_screenshots` | スクショDL → iPad分を自動削除 |
| `fastlane create_app` | 新規アプリレコード作成 |
| `fastlane build_auto` | ビルド（Automatic Signing） |
| `fastlane upload_binary` | IPAをApp Store Connectへアップロード |
| `fastlane upload_metadata` | メタデータ・スクショをアップロード |
| `fastlane submit_review` | 審査提出 |
| `fastlane deploy` | ビルド〜審査提出まで一括実行 |

---

## API キー作成手順

全レーンの実行にAPI キーが必要です。以下の手順で作成してください:

1. https://appstoreconnect.apple.com にログイン
2. 「ユーザとアクセス」→ 上部タブの「統合」→「App Store Connect API」を選択
3. 「キーを生成」（または +ボタン）をクリック
4. 名前: 任意（例: `fastlane`）、アクセス: 「Admin」を選択 → 「生成」
5. 表示される「キー ID」と、ページ上部の「Issuer ID」をメモ
6. 「APIキーをダウンロード」で .p8 ファイルを保存（1回しかダウンロードできません）

作成後の設定:

```
cp fastlane/.env.example fastlane/.env
```

fastlane/.env を編集して値を入れる:

```
ASC_KEY_ID=（手順5のキーID）
ASC_ISSUER_ID=（手順5のIssuer ID）
ASC_KEY_PATH=fastlane/AuthKey_XXXXXXXX.p8
```

.p8 ファイルを fastlane/ ディレクトリに配置する。

---

## 今回の審査対応の手順

API キーを作成したら、以下の順序で進めます:

1. `fastlane download_screenshots` — 既存アプリからスクショをダウンロード（ローカルに保存）
2. App Store Connect で既存のアプリレコードを手動で削除
3. `fastlane create_app` — iPhone専用で新規作成
4. `fastlane fix_screenshots` の代わりに、ダウンロード済みのiPhoneスクショだけを `fastlane/screenshots/` に配置
5. `fastlane deploy` — ビルド → アップロード → メタデータ → 審査提出まで一括実行

API キーができたら教えてください。動作確認を進めます。

## Key Actions

- - **Glob**: **/fastlane/**
- - **Glob**: **/screenshots/**
- - **Glob**: **/*.png
- - **Bash**: Check if fastlane is installed
- - **Bash**: Check Ruby/Bundler availability
- - **Bash**: Check Xcode version
- - **Bash**: Check Homebrew availability
- - **TaskCreate**: fastlane を使った App Store Connect 自動化環境を構築する。
1. fastlane インストール
2. 設定ファイル作成（Fastfile, Appfile等）
3. スクショダウンロード、アプリ作成、ビルド・アップロード、審査提出のレーン作成
4. API キー作成手順の案内
- - **TaskUpdate**: 
- - **Bash**: Install fastlane via Homebrew
