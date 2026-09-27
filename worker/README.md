# Cloudflare Workers版

このディレクトリは、EC2上のRailsを置き換えるWorkers + D1版です。

## 構成

- Worker: `bulkpurchase-worker`
- D1: `bulkpurchase-db`（APAC）
- ログイン: Authentik OAuth2 / OpenID Connect
- 定期実行: 1分ごとのCronでPDF自動送信を確認

稼働確認用のWorker URLは次です。これは移行中の確認用であり、既存の
`bulkpurchase.showway.biz` はまだEC2を向いています。

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

データ移行とWorkerのログイン確認後に、`bulkpurchase.showway.biz/*` のCloudflare Workersルートを `bulkpurchase-worker` に切り替えます。その後、EC2のRailsサービスを停止できます。
