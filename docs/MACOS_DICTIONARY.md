# macOS標準辞書の利用方針

## 語義表示

Dictionary Servicesの`DCSCopyTextDefinition`を使用します

`DCSCopyTextDefinition`へ辞書を指定し、辞書ごとの語義をプレーンテキストで取得します

入力中はローマ字、候補選択中は選択候補を検索し、次の辞書から取得できた語義を専用パネルへ表示します

- スーパー大辞林
- ウィズダム英和辞典・ウィズダム和英辞典
- New Oxford American Dictionary

macOSではウィズダム英和辞典と和英辞典が1つの辞書参照として提供されます

語義は辞書名付きで1つのスクロール領域へ表示します

入力中の同じ文字列に対する再検索を避けるため、直近128件の結果をメモリへ保持します

## 辞書の選別

公開APIである`DCSCopyTextDefinition`は辞書指定を予約済み引数として扱い、公開ドキュメント上は有効な辞書の最初の一致を返します

複数辞書を個別に検索するため、実行環境に存在する次のシステム関数を使用します

- `DCSCopyAvailableDictionaries`
- `DCSDictionaryGetName`

これらはmacOS SDKのリンク対象シンボルには含まれますが、公開ヘッダでは宣言されていません

macOS更新で動作が変わる可能性があるため、各対応OSで実機確認が必要です

## 変換候補の生成

Dictionary Servicesの公開APIが提供する操作は次の2つです

- 指定した語句の語義取得
- 文字列内の検索対象範囲の判定

次の操作を行う公開APIはありません

- 辞書の全見出し語の列挙
- 前方一致する見出し語の列挙
- 辞書本文から変換用インデックスを生成

このため、スーパー大辞林、ウィズダム英和辞典、ウィズダム和英辞典、New Oxford American Dictionaryを直接走査して変換候補を作る実装は行いません

辞書バンドルの内部ファイルを直接解析する方法は、非公開形式への依存とコンテンツの利用条件に問題があるため採用しません

## 英語予測

英語の前方一致候補には`NSSpellChecker`の単語補完APIを使用します

日本語入力から英語候補を生成する機能は未実装です

このAPIは入力途中の文字列から補完候補を返しますが、Dictionary Servicesの辞書本文を検索するものではありません

## 参照

- https://developer.apple.com/documentation/coreservices/dcscopytextdefinition
- https://developer.apple.com/documentation/coreservices/dictionary_services
- https://developer.apple.com/documentation/appkit/nsspellchecker/completions(forpartialwordrange:in:language:inspelldocumentwithtag:)
