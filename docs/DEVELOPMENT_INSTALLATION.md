# 開発用インストール

## 更新

```sh
git pull
./Scripts/install-macos-im.sh
./Scripts/diagnose-installation.sh
```

インストール先は`~/Library/Input Methods/myim.app`

診断結果では次の状態を個別に確認する

- `INSTALL_STATE=matched`はビルド成果物とインストール内容が一致
- `RUN_STATE=running-current`はインストール済みのビルドが現在稼働中
- `RUN_STATE=installed-not-running`はインストール済みだが現在は未起動
- `RUN_STATE=old-running`は現行のインストール先以外の入力メソッドが稼働中
- `HISTORY_STATE=current-matches-installed`は起動記録が現在のプロセスと一致
- `HISTORY_STATE=last-launch-matches-installed`は最後に起動したビルドがインストール内容と一致
- `LEGACY_STATE=selected`は旧名称の入力ソースが選択中
- `RESULT=attention`は表示された不一致や旧名称アプリの確認が必要

`runtime-status.json`は最後の起動履歴
`STATUS=last-launch`だけでは現在稼働中と判断しない

## 旧名称アプリの退避

旧名称`my-ime.app`は現行myimと識別子が異なるため直接競合しない
ただしLaunch Servicesへの登録とアプリ本体が残り、再登録や旧版起動の経路になり得る

現行myimの動作を確認してから次の順序で整理する

1. 入力ソースをABCまたは現行myimへ切り替える
2. 診断結果を保存する
3. 旧名称アプリを削除せずシステム領域内の退避先へ移動する
4. ログアウトとログインを手動で行う
5. 現行myimを選択して入力する
6. 診断結果を再取得して比較する

作業前の記録

```sh
./Scripts/diagnose-installation.sh > "$HOME/myim-diagnosis-before-login.txt"
```

旧名称アプリの退避例

```sh
sudo mkdir -p "/Library/Input Methods Disabled"
sudo mv "/Library/Input Methods/my-ime.app" \
  "/Library/Input Methods Disabled/my-ime.app"
```

ログイン後の記録

```sh
./Scripts/diagnose-installation.sh > "$HOME/myim-diagnosis-after-login.txt"
diff -u \
  "$HOME/myim-diagnosis-before-login.txt" \
  "$HOME/myim-diagnosis-after-login.txt"
```

問題が発生した場合の復元例

```sh
sudo mv "/Library/Input Methods Disabled/my-ime.app" \
  "/Library/Input Methods/my-ime.app"
```

旧名称アプリの登録解除や削除は自動実行しない

## ログアウトとログイン後の判定

次を確認する

- `INSTALL_STATE=matched`
- `RUN_STATE=running-current`または入力前の`installed-not-running`
- 現行myim起動後に`HISTORY_STATE=current-matches-installed`
- 実行パスが`~/Library/Input Methods/myim.app/Contents/MacOS/myim`
- ビルド番号とGitコミットがインストール済みアプリと一致
- 旧名称のプロセスが存在しない
- 設定、ユーザー辞書、学習結果が維持されている

ログアウトとログインはスクリプトから自動実行しない
