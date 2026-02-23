fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios download_screenshots

```sh
[bundle exec] fastlane ios download_screenshots
```

既存アプリからスクリーンショットをダウンロード

### ios download_metadata

```sh
[bundle exec] fastlane ios download_metadata
```

既存アプリからメタデータをダウンロード

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

App Store Connect に新しいアプリレコードを作成（iPhone専用）

### ios build_auto

```sh
[bundle exec] fastlane ios build_auto
```

アプリをビルド（Automatic Signing）

### ios upload_binary

```sh
[bundle exec] fastlane ios upload_binary
```

ビルド済み IPA を App Store Connect にアップロード

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

メタデータとスクリーンショットをアップロード

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

審査に提出

### ios deploy

```sh
[bundle exec] fastlane ios deploy
```

ビルドからApp Store審査提出まで一括実行

### ios fix_screenshots

```sh
[bundle exec] fastlane ios fix_screenshots
```

iPadスクリーンショットを削除してiPhone分のみ残す

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
