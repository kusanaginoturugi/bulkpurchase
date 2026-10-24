# 脆弱性点検と対策

手順は kusanaginoturugi/www の `docs/security-runbook.md` に従う。この repo は
Cloudflare Workers + D1 (npm) なので、Hugo 本体・テーマ・Cloudflare Pages の節は対象外。

## 2026-10-24 作業記録

### 依存

- 開発用依存を更新: wrangler 4.149.0 → 4.152.0、vitest 5.0.3 → 5.0.5、
  @cloudflare/workers-types 5.20261010.1 → 5.20261024.1。
- `npm audit`: 更新前後とも 3 件 (high 1、moderate 2)。すべて
  wrangler → miniflare → undici 7.29.1 の経路 (GHSA-4qv8-2p9j-2685、GHSA-f72v-6w45-q472、
  GHSA-xjj6-f33q-929c)。undici はローカル開発サーバーとデプロイ CLI だけが使い、
  `src/` からは import されず Worker にバンドルされない。
- `npm audit --omit=dev`: 0 件。
- `npm audit fix --force` は wrangler 4.35.0 へのダウングレードになるため実行しない。
  override も入れない。wrangler が undici 7.31 以降を使う版になったら解消する。

### コード

- 全レスポンスに Hono の `secureHeaders` でセキュリティヘッダーを付ける。
  - CSP: `script-src 'self' 'nonce-…'`。画面の inline script 2つにリクエストごとの nonce を付ける。
  - `style-src 'unsafe-inline'`: `ui.ts` が `<style>` を動的に追加するため必要。
  - X-Frame-Options DENY、nosniff、Referrer-Policy strict-origin-when-cross-origin、
    Permissions-Policy、HSTS `max-age=31536000` (includeSubDomains / preload なし)。
- セッション用 Cookie の署名と CSRF トークンの比較を定数時間比較にした。
- ログイン失敗画面のエラーメッセージを HTML エスケープする。
- 確認済みで変更しなかった点: Cookie は HttpOnly・Secure・SameSite=Lax。OIDC は
  state・nonce を検証。API は CSRF トークン必須。D1 は prepared statement。
  画面の動的 HTML は `esc()` でエスケープ。`/logout` は GET (影響が小さいため据え置き)。
  リクエスト本文の上限はログイン後の API だけで、Workers の上限に任せる。

### GitHub

- CI: Actions を commit SHA で固定、`permissions: contents: read`、`persist-credentials: false`、
  週次実行、`npm audit --omit=dev --audit-level=high` を追加。
- CodeQL (`actions`、`javascript-typescript`、security-extended) と Dependency Review を追加。
- Dependabot 脆弱性アラートを有効化。`.github/dependabot.yml` は既存の方針
  (`docs/dependency-updates.md`) のまま。Dependabot security updates と main の保護設定は変更しない。
- Secret scanning と push protection は有効済み。

### 検証

- `npm run check`、`wrangler deploy --dry-run` (本体・edge-proxy)。
- ローカルの `wrangler dev` で、`/health`・未ログインの 302・ログイン後の画面にヘッダーが付くこと、
  CSP の nonce と script タグの nonce が一致すること、CSRF トークンの不一致が拒否されることを確認。

### 引き継ぎ

- 本体 Worker は Cloudflare アカウント `11491c…` にあり、`kusanaginoturugi@gmail.com` の
  Wrangler ログインではデプロイできない。本体のアカウントでログインして
  `cd worker && npm run deploy` を実行し、次で本番のヘッダーを確認する。
  edge-proxy は変更していないので再デプロイ不要。

```sh
curl -sSI https://bulkpurchase.showway.biz/ | grep -iE 'content-security|x-frame|strict-transport|permissions-policy'
```
