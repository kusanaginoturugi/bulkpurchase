# Cloudflare Workers版

このディレクトリは、EC2上のRailsを置き換えるWorkers + D1版です。

## 構成

- Worker: `bulkpurchase-worker`
- D1: `bulkpurchase-db`（APAC）
- ログイン: Authentik OAuth2 / OpenID Connect
- 定期実行: 1分ごとのCronでPDF自動送信を確認

本番URLは次です。Authentikログインと注文入力は、このURLから行います。

```text
https://bulkpurchase.showway.biz/
```

本体WorkerのURLは次です。D1データベースと本体Workerは、D1を作成済みの
Cloudflareアカウントにあります。

```text
https://bulkpurchase-worker.myouougoma.workers.dev/health
```

## 初回設定

```bash
cd worker
cp .dev.vars.example .dev.vars
npm install
npm run d1:migrate:remote
```

CloudflareのWorker秘密値として、次を設定します。値はGitHubの既存秘密設定から引き継ぎます。

```bash
npx wrangler secret put AUTHENTIK_CLIENT_SECRET
npx wrangler secret put SESSION_SECRET
# 通知メールを使う場合だけ設定
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put RESEND_FROM
```

既存の Authentik プロバイダにはすでに次のURLが登録されています。このURLは
Worker版でも継続して利用するため、本番切替のためにプロバイダを作り直す必要は
ありません。

```text
https://bulkpurchase.showway.biz/session/authentik/callback
```

Workers の確認用URLでログイン動作まで確認する場合だけ、次のURLを追加します。

```text
https://bulkpurchase-worker.<workers.devのサブドメイン>/auth/callback
```

## Railsデータの移行

Railsサーバー上で出力し、Cloudflareへ適用します。

```bash
RAILS_ENV=production bin/rails runner script/export_d1_data.rb > /tmp/rails-data.sql
cd worker
./scripts/import-rails-data.sh /tmp/rails-data.sql
```

## 独自ドメインの中継

`showway.biz` のゾーンとD1を保有するアカウントが異なるため、`edge-proxy/` の
`bulkpurchase-edge` が `bulkpurchase.showway.biz` のカスタムドメインを受け、本体
Workerへ中継します。これにより、D1データを複製せずに独自ドメインで運用できます。

```bash
npx --prefix worker wrangler deploy --config edge-proxy/wrangler.jsonc
```

カスタムドメインを使うため、同じホスト名のDNS CNAMEレコードは作成しません。切替後は
EC2のRailsサービスを停止できます。
