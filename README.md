# voicetrans

## バージョン

```
node：15.5.0
npm：7.3.0
@vue/cli 4.5.9
```

## Project setup

```
npm install
```

### Compiles and hot-reloads for development

```
npm run serve
```

## 起動方法(docker)

```
cd app
docker build -t voicetrans .
docker run -d -p 80:80 voicetrans
```

docker で起動すると basic 認証がかかります
(Dockerfile 内でべた書きしてます)
ユーザ ID：voicetrans
パスワード：mrdDeu78

## 画面役割・機能説明

### /

- お客さんに見せる用の画面。お客さんの要望に対応する際はこちらで対応。
- 機能
  - 日本語文字起こし
  - 日本語 ⇒ 英語の翻訳
  - 画面のリセット
  - 開発画面への遷移
    - Insert +「開発」の声(お客さんにはバレないはず。。)

### /dev

- 開発に使用する実験用画面。サーバーサイドとの連携もこの画面で実装中。
- デザイン調整が面倒なのでボタンではなく音声コマンドにしています。
- 機能
  - 日本語文字起こし
  - 日本語 ⇒ 英語の翻訳
  - 画面のリセット
    - Insert +「リセット」の声
  - CSV ダウンロード
    - Insert +「CSV ダウンロード」の声
  - 指定行の音声ダウンロード
    - 行を指定したうえで、Insert +「音声ダウンロード」の声
  - ホーム画面への遷移
    - Insert +「ホーム」の声

## デプロイ

```
voicetrans.azurecr.ioに向けてimageをpush
docker tag voicetrans:latest voicetrans.azurecr.io/voicetrans_voicetrans:latest
docker push voicetrans.azurecr.io/voicetrans_voicetrans:latest

```

コンテナレジストリと webapps を繋げているのでレジストリの push のみで大丈夫です。
まだ POC で構成が変わっていくだろうということもあり、DevOps からのパイプラインは作ってません。  
backend はローカルで試している段階なので、デプロイしたことはありません。

### 精度向上案

フレーズリストの追加
似たフレーズのとき優先させることができるらしい
https://docs.microsoft.com/ja-jp/azure/cognitive-services/speech-service/get-started-speech-to-text?tabs=windowsinstall&pivots=programming-language-python#%E8%AA%8D%E8%AD%98%E3%81%AE%E7%B2%BE%E5%BA%A6%E3%82%92%E5%90%91%E4%B8%8A%E3%81%95%E3%81%9B%E3%82%8B

custom speech で精度向上できるかも？
https://docs.microsoft.com/ja-jp/azure/cognitive-services/speech-service/custom-speech-overview

テナントに特化したモデルを作れるらしい
北米リージョンだけではあるが、英語だけかどうかは不明
https://docs.microsoft.com/ja-jp/azure/cognitive-services/speech-service/tutorial-tenant-model

### Compiles and minifies for production

```
npm run build
```

### Lints and fixes files

```
npm run lint
```

### Customize configuration

See [Configuration Reference](https://cli.vuejs.org/config/).
