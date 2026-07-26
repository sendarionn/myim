# my-ime

共有辞書を使うIMEのコマンドライン版モックアップ

## 必要環境

- macOS 13以降
- Swift 6以降

## 実行

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
Cosense: https://scrapbox.io/sendarionn/%E8%A6%8B%E3%82%8B
```

空のままEnterを押すと終了します

## 辞書

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
