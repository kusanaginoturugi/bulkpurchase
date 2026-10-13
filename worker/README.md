# Cloudflare Workers 版

注文画面・API・PDF 生成・定期送信を提供する本体 Worker です。D1 は
`bulkpurchase-db`、本番 URL は `https://bulkpurchase.showway.biz/` です。
独自ドメインのリクエストは `edge-proxy/` が中継します。

## 開発と確認

```bash
cd worker
npm ci
cp .dev.vars.example .dev.vars
npm run d1:migrate:local
npm run dev
npm run check
npx wrangler deploy --dry-run
npx wrangler deploy --dry-run --config ../edge-proxy/wrangler.jsonc
```

`.dev.vars` はローカル用で、Git に含めません。

## 本番設定とデプロイ

`wrangler.jsonc` に本体 Worker と D1 の接続先があります。`edge-proxy/wrangler.jsonc`
には独自ドメインの設定があります。両 Worker は別の Cloudflare アカウントです。
デプロイ前に対象アカウントを確認してください。

本体 Worker には `AUTHENTIK_CLIENT_SECRET` と `SESSION_SECRET` が必要です。
通知メールを使う場合は `RESEND_API_KEY` と `RESEND_FROM` も設定します。
秘密値は Wrangler Secret に保管します。

```bash
cd worker
npm run d1:migrate:remote
npm run deploy
npx wrangler deploy --config ../edge-proxy/wrangler.jsonc
```

Authentik の登録済み戻り先は
`https://bulkpurchase.showway.biz/session/authentik/callback` です。
本体 Worker の確認用 URL は
`https://bulkpurchase-worker.myouougoma.workers.dev/health` です。

## データ保全

本番 D1 のエクスポート例。ファイルには注文と個人情報が含まれるため、Git 管理外の
安全な場所に置いてください。

```bash
cd worker
mkdir -p ../backups
npx wrangler d1 export bulkpurchase-db --remote --output ../backups/bulkpurchase-db.sql
```

Rails 版は廃止作業中です。旧ソースと移行用スクリプトは Git コミット `9e39fe9` にあります。
廃止の進捗と本番での確認項目は `docs/rails-retirement.md` を参照してください。
