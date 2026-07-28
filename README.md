# myim

Cosenseの共有辞書を使うmacOS向けInput Method

実装の更新履歴は`HISTORY.md`を参照してください

## 必要環境

- macOS 13以降
- Swift 6以降

## 現在の動作

- 英字キーで入力したローマ字を未確定文字列としてそのまま表示
- 入力または削除のたびにローマ字の前方一致候補を更新
- 候補は文字列の長さに合わせた可変幅セルで縦横に表示
- 候補パネルは入力位置の近くでディスプレイ内に収まるよう配置
- Spaceで先頭候補を選択
- 続けてSpaceを押すと次候補へ移動
- 候補を選択した時点で未確定文字列を候補のひらがなや漢字へ切り替え
- 選択候補に対応する指定辞書の語義とCosenseページを小窓で表示
- 候補選択中のReturnで選択候補を確定
- 候補未選択のReturnで入力したローマ字を確定
- Deleteで入力中の文字を削除して候補を再検索
- Escapeで候補選択を解除してローマ字表示へ戻る

入力中のローマ字は候補を選択するまで変換しません

macOS標準辞書の利用範囲と変換候補への利用方針は`docs/MACOS_DICTIONARY.md`を参照してください

語義は次の辞書から個別に取得し、1つのスクロール領域へまとめて表示します

- スーパー大辞林
- ウィズダム英和辞典・ウィズダム和英辞典
- New Oxford American Dictionary

ウィズダム英和辞典と和英辞典はmacOS上で1つの辞書として提供されます

## Cosense辞書

次の公開ページを使用します

```text
https://scrapbox.io/sendarionn-public/dictionary
```

読みをインデントなしで記述し、その候補を1文字以上インデントします

読みには入力に使用するローマ字を記述します

```text
miru
 見る
 診る
 観る

ikiru
 生きる
 活きる
```

同じ読みが複数回現れた場合は候補を記述順に統合します

重複した候補は最初の候補だけを残します

### 実行中の辞書更新

次のどちらかでCosenseの変更を読み込みます

- 入力ソースメニューから「Cosense辞書を更新」を選択
- `Command＋Shift＋R`を押す

更新した辞書は次の場所へ保存されます

```text
~/Library/Application Support/my-ime/dictionary.txt
```

更新に成功すると実行中の変換辞書へ即時反映されます

IMの再起動は不要です

更新に失敗した場合は現在の辞書を維持します

## ビルドとインストール

IMバンドルをビルドします

```shell
./Scripts/build-macos-ime.sh
```

ユーザー用Input Methodsへインストールし、入力ソースを再登録します

```shell
./Scripts/install-macos-im.sh
```

初回のみ「システム設定」→「キーボード」→「テキスト入力」→「編集」から`my-ime`を追加します

更新時は同じ2つのコマンドを再実行します

ログアウトや再起動は不要です

インストール先は次の場所です

```text
~/Library/Input Methods/my-ime.app
```

## コマンドライン版

辞書の確認にはコマンドライン版を使用できます

```shell
swift run my-ime
```

Cosense辞書をコマンドラインから同期する場合は次を実行します

```shell
swift run my-ime sync
```

任意の辞書ファイルを確認する場合はパスを指定します

```shell
swift run my-ime /path/to/dictionary.txt
```

## テスト

```shell
swift test
```
