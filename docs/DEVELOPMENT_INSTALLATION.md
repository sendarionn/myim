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
- `SESSION_STATE=verified`は`--client-bundle-id`で指定した入力先アプリが現在のビルドで入力セッションを開始済み
- `SESSION_STATE=current-observed`は表示された入力先アプリで現在のビルドの入力セッションを確認済み
- `SESSION_STATE=unverified`は入力先アプリの入力セッションが未確認
- `RUN_STATE=installed-not-running`はインストール済みだが現在は未起動
- `RUN_STATE=old-running`は現行のインストール先以外の入力メソッドが稼働中
- `HISTORY_STATE=current-matches-installed`は起動記録が現在のプロセスと一致
- `HISTORY_STATE=last-launch-matches-installed`は最後に起動したビルドがインストール内容と一致
- `LEGACY_STATE=selected`は旧名称の入力ソースが選択中
- `RESULT=attention`は表示された不一致や旧名称アプリの確認が必要
- `RESULT=installed-verified`はインストール、実行中プロセス、表示された入力セッションが一致
- `RESULT=installed-session-unverified`はインストールと実行中プロセスは正常だが入力セッションが未確認

`runtime-status.json`は最後の起動履歴
`STATUS=last-launch`だけでは現在稼働中と判断しない

入力先アプリを指定する場合

```sh
./Scripts/diagnose-installation.sh \
  --client-bundle-id com.apple.TextEdit
```

別アプリの入力セッション記録は、指定したアプリの検証結果として扱わない

`installed-session-unverified`の場合は次の順に確認する

1. 入力ソースを別のものへ切り替え、myimへ戻す
2. 入力欄へフォーカスし直す
3. 未確認のままなら入力先アプリを再起動する
4. 対象のBundle IDを指定して診断を再実行する

入力先アプリの強制終了はインストール処理から行わない

## 旧名称アプリのクリーンアップ

旧名称`my-ime.app`は現行myimと識別子が異なるため直接競合しない
ただしLaunch Servicesへの登録とアプリ本体が残り、再登録や旧版起動の経路になり得る

`install-macos-im.sh`は、次の条件をすべて確認できた旧アプリだけを自動削除する

- 配置先が`~/Library/Input Methods/my-ime.app`または`/Library/Input Methods/my-ime.app`
- Bundle Identifierが`io.github.sendarionn.my-ime`
- 実行ファイル名が`my-ime`
- 現行`myim.app`と異なるパス
- 旧入力ソースが選択されていない
- 旧`my-ime`プロセスが動作していない

条件を確認できない場合は削除せず、`LEGACY_CLEANUP=skipped`と理由を表示する
システム領域からの削除だけは管理者認証を求める

削除時は旧入力ソースを無効化し、Launch Servicesの登録を解除してからアプリ本体を削除する
macOSには登録済み入力ソースを直接削除する公開APIがないため、アプリ削除後に入力ソース一覧から消えたことも確認する

クリーンアップ後の確認

```sh
./Scripts/diagnose-installation.sh
```

次を確認する

- `LEGACY_STATE=not-installed`
- 実行中プロセスに`my-ime`がない
- `legacy-registered=0`
- `legacy-enabled=0`
- `legacy-selected=0`

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
