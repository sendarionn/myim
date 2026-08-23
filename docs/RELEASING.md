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
