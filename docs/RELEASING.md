# リリース手順

ローカル環境でUniversal BinaryのPKGを作成し、Developer ID署名とApple公証を行います

## 必要な証明書

- Developer ID Application
- Developer ID Installer

証明書はログインKeychainへ読み込んでおきます

## リリース

下記のローカル検証で作成した次のファイルをGitHub Releaseへ手動で追加します

- `myim-0.1.0.pkg`
- `myim-0.1.0.pkg.sha256`

PKGは`/Library/Input Methods/myim.app`へ配置します
既存アプリの再配置を禁止し、同じ場所で更新します
更新時は実行中のmyimと外部情報ブラウザを終了します

開発用インストールは`~/Library/Input Methods/myim.app`を使用します
同じBundle Identifierの開発版とPKG版は併存させません

## ビルドと公証

Keychainへ公証資格情報を保存します

```shell
xcrun notarytool store-credentials myim-notary
```

署名済みPKGを作成して公証します

```shell
MYIM_VERSION=0.1.0 \
MYIM_BUILD_NUMBER=1 \
MYIM_CODE_SIGN_IDENTITY="Developer ID Application: 名前 (TEAMID)" \
MYIM_INSTALLER_SIGN_IDENTITY="Developer ID Installer: 名前 (TEAMID)" \
./Scripts/build-release-pkg.sh

./Scripts/notarize-release-pkg.sh \
  .build/release-artifacts/myim-0.1.0.pkg
```

## 更新結果の確認

ビルド成果物にはバージョン、ビルド番号、Gitコミット、変更状態、ビルド日時を記録します

インストール先、実行中プロセス、起動時のビルド情報をまとめて確認します

```shell
./Scripts/diagnose-installation.sh
```

確認対象

- 同じBundle Identifierのアプリが複数の場所に存在しないこと
- ビルド成果物とインストール済みアプリのSHA-256とリソースが一致すること
- 実行中プロセスのパスがインストール先と一致すること
- 起動時に記録したビルド番号とGitコミットがインストール済みアプリと一致すること
- 入力ソースの登録、有効化、選択状態

結果は次の状態で出力します

- `RESULT=healthy`は検出した状態に矛盾がない
- `RESULT=attention`は重複、旧名称のアプリ、署名不良、識別情報不足、異なる実行パスなどの確認が必要
- `RESULT=installed-running`は開発版の置換と新しいプロセスの起動を確認済み
- `RESULT=installed-not-selected`は置換済みだが現在の入力ソースではない
- `RESULT=installed-launch-unverified`は置換済みだが新しいプロセスの起動を確認できていない

PKG更新後は自動起動を成功条件にしません
インストール済みアプリの署名と識別情報を検証し、`RESULT=installed-not-running`として終了します
入力欄へフォーカスしてmyimを起動した後、診断スクリプトで実行中のビルドを確認します
