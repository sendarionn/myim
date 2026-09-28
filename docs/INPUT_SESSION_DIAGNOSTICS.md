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
- event
- composition
- marked range
- selected range

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
