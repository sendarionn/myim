# myim

共有辞書を使うInput Method

実装の更新履歴は`HISTORY.md`を参照してください

## 必要環境

- macOS 13以降
- Swift 6以降

## 実行

初回は同梱テスト辞書を使用します

```shell
swift run my-ime
```

読みを入力すると完全一致した候補が表示されます

```text
my-ime
読みを入力してください
終了するには空のままEnterを押してください
> miru
1  見る
2  診る
3  観る
候補番号> 1
確定: 見る
Cosense: https://scrapbox.io/sendarionn-public/%E8%A6%8B%E3%82%8B
```

空のままEnterを押すと終了します

## Cosense辞書

次の公開ページを辞書として使用します

```text
https://scrapbox.io/sendarionn-public/dictionary
```

手動で同期します

```shell
swift run my-ime sync
```

macOS版IMの実行中は次のどちらかで更新できます

- 入力ソースメニューから「Cosense辞書を更新」を選択
- `Command＋Shift＋R`を押す

更新に成功するとキャッシュと実行中の変換辞書が同時に更新されます

IMの再起動は不要です

入力ソースメニューには更新中、完了、失敗の状態が表示されます

取得した辞書は次の場所へ保存されます

```text
~/Library/Application Support/my-ime/dictionary.txt
```

同期に成功すると、次回からキャッシュ済み辞書を使用します

通信または辞書解析に失敗した場合、既存のキャッシュは上書きされません

## 辞書形式

同梱辞書は`Sources/MyIME/Resources/dictionary.txt`にあります

読みをインデントなしで、その候補を1文字以上インデントして記述します

```text
miru
 見る
 診る
 観る

ikiru
 生きる
 活きる
```

別の辞書ファイルを使う場合はパスを指定します

```shell
swift run my-ime /path/to/dictionary.txt
```

同じ読みが複数回現れた場合は候補を記述順に統合します

重複した候補は最初の候補だけを残します

## テスト

```shell
swift test
```

## macOS IM

macOS版IMはInputMethodKitを使用します

事前にコマンドライン版でCosense辞書を同期します

```shell
swift run my-ime sync
```

IMバンドルを作成します

```shell
./Scripts/build-macos-ime.sh
```

次の場所にアドホック署名済みバンドルが作成されます

```text
.build/my-ime.app
```

動作確認する場合は手動でインストールします

```shell
mkdir -p "$HOME/Library/Input Methods"
ditto .build/my-ime.app "$HOME/Library/Input Methods/my-ime.app"
```

インストール後に一度ログアウトして再ログインします

「システム設定」→「キーボード」→「テキスト入力」→「編集」から`my-ime`を追加します

更新したバンドルをインストールする場合は、既存のバンドルを削除してからコピーします

```shell
ditto .build/my-ime.app "$HOME/Library/Input Methods/my-ime.app"
```

Bundle IdentifierはInputMethodKitが入力ソースとして分類できる形式にします

```text
io.github.sendarionn.inputmethod.myime
```

### 操作

- 英字キーで読みを入力すると未確定のローマ字が表示されます
- 入力中は読みの前方一致候補が常に表示されます
- 候補は1文字入力または削除するたびに更新されます
- 候補数が多い場合は縦横のグリッドに最大4列で表示されます
- 候補パネルは入力位置に近い画面内へ収まるよう配置されます
- 候補表示直後は何も選択されていません
- Spaceで先頭候補を選択し、続けて押すと次候補へ移動します
- 候補を移動すると対応するCosenseページが小窓に表示されます
- 候補選択中にReturnを押すと選択候補を確定します
- 候補未選択でReturnを押すと入力したローマ字を確定します
- Deleteで入力中の文字を削除し、候補を再検索します
- Escapeで候補選択を解除し、ローマ字表示へ戻します
- `Command＋Shift＋R`でCosense辞書を更新します

現段階ではローマ字からかなへの変換を行わず、`miru`のような辞書の読みを直接入力します

英語の予測変換とIMからCosense辞書へ登録する機能は今後実装します
