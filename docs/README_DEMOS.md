# README機能紹介と動作GIF

## 管理対象

`docs/readme-demos.json`をREADMEの機能紹介、GIF、関連実装の対応関係の正本とする

各機能は次を保持する

- `id` 固定の機能ID
- `published` READMEへの掲載有無
- `status` `active`、`retired`、判断保留の`uncertain`
- `description` READMEへ表示する説明
- `image` READMEへ掲載するGyazoのGIF
- `watchPaths` ユーザー向け動作へ影響する実装
- `verifiedSourceHash` 最後にGIFを確認した関連実装のhash

関数名やファイル名が見つからないだけで`retired`へ変更しない
廃止を実装、履歴、実操作から確認できない機能は`uncertain`として残す

## 操作

関連実装が変わり、手動で確認が必要なデモと、READMEの差分を確認する

```shell
./Scripts/update-readme-demos.sh --dry-run
```

定義からREADMEの管理区間を同期する

```shell
./Scripts/update-readme-demos.sh
```

READMEの画像はGyazoで管理する
公開対象の`image.path`には`https://gyazo.com/`から始まるURLだけを許可する

## ファイル構成

```text
docs/
  readme-demos.json
Scripts/
  readme_demos.py
  update-readme-demos.sh
```

READMEでは`README_DEMOS`マーカー内だけを生成する
それ以外の手動記述は変更しない
