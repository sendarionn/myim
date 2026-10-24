# 入力セッション診断

診断機能は環境変数を設定したInputMethodKitプロセスでのみ有効になる

## セッショントレース

```sh
launchctl setenv MYIM_SESSION_TRACE 1
./Scripts/install-macos-im.sh
```

ログの確認

```sh
log stream --style compact --predicate 'subsystem == "com.sendarionn.myim" AND category == "input-lifecycle"'
```

トレースには以下を出力する

- session generation
- input revision
- controller ID
- source application
- myimのPID、ビルド番号、Gitコミット
- event
- composition
- marked range
- selected range

入力セッションが有効になるたびに、入力内容を含まない識別情報を次へ保存する

```text
~/Library/Caches/myim/input-sessions/<入力先Bundle ID>.json
```

記録項目

- 入力先アプリのBundle ID
- myimのPID
- ビルド番号とGitコミット
- InputController ID
- session generation
- activation time

記録は入力先アプリ単位で分離する
TextEditの記録をChromeやVS Codeのセッション確認には使用しない

対象アプリの確認例

```sh
./Scripts/diagnose-installation.sh \
  --client-bundle-id com.apple.TextEdit
```

入力文字列と候補文字列は記録しない

診断終了

```sh
launchctl unsetenv MYIM_SESSION_TRACE
./Scripts/install-macos-im.sh
```

## 機能別の停止

```sh
launchctl setenv MYIM_DIAGNOSTIC_DISABLE dictionaryPanel,externalInformationPanel
```

指定可能な値

- `dictionaryPanel`
- `externalInformationPanel`
- `translation`
- `fuzzySuggestion`
- `nextInput`
- `jsExtensions`
- `learning`

lookupを動かしたままパネル表示だけを止める場合

```sh
launchctl setenv MYIM_DIAGNOSTIC_HIDE_PANELS dictionaryPanel,externalInformationPanel
```

最小構成

```sh
launchctl setenv MYIM_DIAGNOSTIC_MINIMAL 1
```

設定変更後は`./Scripts/install-macos-im.sh`でInputMethodKitプロセスを入れ替える

診断終了時は設定した変数を`launchctl unsetenv`で解除する
