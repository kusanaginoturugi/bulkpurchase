# 依存更新の運用

## 計画

- Dependabot の更新確認を週1回にする。
- Worker の開発用と本番用の minor・patch 更新を、それぞれ1本の PR にまとめる。
- major 更新とセキュリティ更新は個別に確認する。

## 2026-10-13 作業記録

- `.github/dependabot.yml` に npm の2グループと GitHub Actions の minor・patch グループを設定。
- 更新確認の頻度を daily から weekly に変更。
- 設定変更前の個別 PR（例: #34 Wrangler、#35 Vitest、#36 Workers types、#37 Hono）は開いたまま。新設定が既存 PR を自動的にまとめるとは確認していない。
- Rails 削除前に作られた Bundler 更新 PR がまだ開いている。現行アプリには適用しない。

## 引き継ぎ

- GitHub Actions の CI 結果と、次回 Dependabot 実行時にグループ PR が作成されるかを確認する。
- 旧 Rails 用 PR を閉じる。GitHub CLI の認証が失効しているため、この環境からは PR を操作できない。
- グループ PR でも変更内容と CI 結果を確認してからマージする。major 更新は個別に扱う。
