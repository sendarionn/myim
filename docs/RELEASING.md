# リリース手順

GitHub ActionsでUniversal BinaryのPKGを作成し、Developer ID署名、Apple公証、Staple、GitHub Releaseへの添付まで実行します

## 必要な証明書

- Developer ID Application
- Developer ID Installer

秘密鍵を含む2つの証明書を1つのP12へ書き出し、Base64へ変換します

```shell
base64 -i certificates.p12 | pbcopy
```

## GitHub Actions Secrets

リポジトリのSettings → Secrets and variables → Actionsへ次を登録します

| Secret | 内容 |
| --- | --- |
| `APPLE_CERTIFICATES_P12_BASE64` | P12のBase64文字列 |
| `APPLE_CERTIFICATES_PASSWORD` | P12のパスワード |
| `APPLE_KEYCHAIN_PASSWORD` | Actions内の一時Keychain用パスワード |
| `APPLE_APPLICATION_IDENTITY` | `Developer ID Application: 名前 (TEAMID)` |
| `APPLE_INSTALLER_IDENTITY` | `Developer ID Installer: 名前 (TEAMID)` |
| `APPLE_ID` | Apple Developer AccountのApple ID |
| `APPLE_TEAM_ID` | Apple Developer Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | Apple IDのアプリ用パスワード |

証明書やパスワードをリポジトリへ追加しません

## リリース

バージョン番号のタグを作成してpushします

```shell
git tag v0.1.0
git push origin v0.1.0
```

Releaseワークフローが成功すると、次のファイルをGitHub Releaseへ追加します

- `myim-0.1.0.pkg`
- `myim-0.1.0.pkg.sha256`

PKGは`/Library/Input Methods/myim.app`へ配置します
既存アプリの再配置を禁止し、同じ場所で更新します
更新時は実行中のmyimと外部情報ブラウザを終了します

## ローカル検証

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
