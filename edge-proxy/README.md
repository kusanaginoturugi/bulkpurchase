# 独自ドメイン中継Worker

`bulkpurchase.showway.biz` を、本体Worker
`https://bulkpurchase-worker.myouougoma.workers.dev` へ中継します。

このWorkerは `showway.biz` のCloudflareアカウントにあり、本体WorkerとD1は別の
Cloudflareアカウントにあります。Authentikの戻り先URLを維持するため、`X-Bulkpurchase-Host`
ヘッダーで本体Workerへ独自ドメイン名を伝えます。

デプロイ:

```bash
npx --prefix worker wrangler deploy --config edge-proxy/wrangler.jsonc
```
