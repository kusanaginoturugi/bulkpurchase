# 聖明王院道具一括注文システム

Cloudflare Workers + D1 で動く注文集約アプリです。本番入口は
`https://bulkpurchase.showway.biz/` です。

## 構成

- `worker/`: 注文画面、API、PDF 生成、定期送信、D1 マイグレーション
- `edge-proxy/`: 独自ドメインから本体 Worker への中継
- `worker/README.md`: 開発、設定、デプロイ手順
- `docs/rails-retirement.md`: Rails 版の廃止状況とデータ保全の確認項目
- `docs/dependency-updates.md`: Dependabot 更新 PR の運用
- `docs/security-maintenance.md`: 脆弱性点検と対策の記録

## ローカル確認

```bash
cd worker
npm ci
npm run check
npm exec wrangler -- deploy --dry-run
```

Rails 版の最後の状態は Git コミット `9e39fe9` に残っています。Rails の本番データは
Git に含まれません。
