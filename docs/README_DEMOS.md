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
- `recording` 自動録画に対応する場合のシナリオと期待結果
- `verifiedSourceHash` 最後に正常なGIFを生成した関連実装のhash

関数名やファイル名が見つからないだけで`retired`へ変更しない
廃止を実装、履歴、実操作から確認できない機能は`uncertain`として残す

## 操作

更新予定だけを確認する

```shell
./Scripts/update-readme-demos.sh --dry-run
```

関連実装が変わった自動録画対応デモを更新する

```shell
./Scripts/update-readme-demos.sh
```

特定のデモを更新する

```shell
./Scripts/update-readme-demos.sh modeless-input
```

すべての自動録画対応デモを更新する

```shell
./Scripts/update-readme-demos.sh --all
```

録画せず、定義からREADMEだけを同期する

```shell
./Scripts/update-readme-demos.sh --readme-only
```

## 録画

初期実装では`modeless-input`を自動録画する

録画処理は次の順で実行する

1. myim入力ソースへ一時的に切り替える
2. 個人情報を含まない専用のテキスト入力ウィンドウを開く
3. 定義されたキー操作を実行する
4. ウィンドウ範囲だけをPNGフレームとして取得する
5. 確定結果が期待値と一致することを確認する
6. 検証用GIFを`.build/readme-demo-artifacts`へ生成する
7. READMEのGyazo URLは変更せず、検証hashだけを更新する
8. 実行前の入力ソースへ戻す

macOSの画面収録権限が必要になる
録画用入力欄へAppKitイベントを直接配信し、他のアプリを操作するアクセシビリティ権限は使用しない
録画や結果確認に失敗した場合、READMEと検証hashは更新しない

自動録画シナリオがない機能は`--dry-run`で手動確認対象として表示する
READMEの画像はGyazoで管理し、検証用のローカルGIFへ自動で切り替えない
公開対象の`image.path`には`https://gyazo.com/`から始まるURLだけを許可する

## ファイル構成

```text
docs/
  readme-demos.json
.build/
  readme-demo-artifacts/
    modeless-input.gif
Scripts/
  readme_demos.py
  record-readme-demo.swift
  update-readme-demos.sh
```

READMEでは`README_DEMOS`マーカー内だけを生成する
それ以外の手動記述は変更しない
