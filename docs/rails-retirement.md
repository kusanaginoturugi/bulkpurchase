# Rails 版廃止の引き継ぎ

## 作業計画

1. Rails 版のソースと自動デプロイをリポジトリから除外し、Worker の CI とドキュメントを整える。
2. 変更を commit・push し、GitHub Actions と Dependabot の動作を確認する。
3. 本番データのバックアップ、業務フローの確認、旧 EC2 と不要な秘密情報の整理を行う。

## 2026-10-13 時点の作業記録

- Rails 版ソースを作業ツリーから削除。削除前のコミットは `9e39fe9`。
- GitHub Actions の Rails テストと EC2 への自動デプロイを除去し、Worker の型検査と両 Worker のビルド確認に変更。
- Dependabot の対象を Bundler から `worker/` の npm に変更。
- 本番サービス、D1、EC2、GitHub の設定は変更していない。
- 本番 URL の `/health` は HTTP 200 と `{"ok":true}` を確認。ログイン以降の業務フローは未確認。
- この環境の GitHub CLI 認証は失効している。Wrangler の API トークンが参照するアカウントは `c584ab0eba9fc9997b7034e844ac014a` で、本体 D1 の設定アカウント `11491cf81519cdab52ed4cd993a11a2b` と異なる。本番 D1 と EC2 のバックアップは未実施。
- `npm ci` 時点の npm audit は high 5 件を報告。対象は Wrangler とその開発用依存。本番依存のみの `npm audit --omit=dev` は 0 件。Dependabot の npm 更新 PR で対処を追跡する。
- ユーザーからバックアップ前の commit・push を明示的に指示された。本番データと旧 EC2 は削除しない。

## 本番側で済ませること

1. Rails の最終 production SQLite DB と添付ファイルがある場合はそれらを、安全な場所へバックアップし、復元できることを確認する。DB や秘密情報を Git に入れない。
2. D1 の本番 DB `bulkpurchase-db` を `worker/README.md` のコマンドでエクスポートして保管し、復元手順を確認する。対象アカウントと DB 名を実行前に確認する。
3. `https://bulkpurchase.showway.biz/health`、ログイン、注文の保存・提出、管理画面、PDF 生成、定期送信結果を確認する。定期送信は実際の月次サイクルで一度確認する。
4. EC2 の Rails サービスが停止していることを確認する。稼働していれば、Worker への切替とデータ保全を確認した上で停止する。
5. push 後に GitHub Actions の CI が通ることを確認する。
6. GitHub の Settings → Advanced Security で Dependabot alerts と Dependabot security updates の有効化状況を確認する。`dependabot.yml` は npm のバージョン更新 PR を設定済み。
7. 復旧に不要と判断できたら、EC2 と Rails 専用の GitHub Secrets、Authentik 設定を整理する。

## 復旧の参照先

Rails のソースと移行用エクスポートスクリプトは `9e39fe9` にある。本番の SQLite DB と
Cloudflare D1 のデータは Git 履歴にはない。コードの復元だけではデータは戻らない。
