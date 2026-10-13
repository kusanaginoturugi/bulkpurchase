# 依存更新の運用

## 計画

- Dependabot の更新確認を週1回にする。
- Worker の開発用と本番用の minor・patch 更新を、それぞれ1本の PR にまとめる。
- major 更新とセキュリティ更新は個別に確認する。

## 2026-10-13 作業記録

- `.github/dependabot.yml` に npm の2グループと GitHub Actions の minor・patch グループを設定。
- 更新確認の頻度を daily から weekly に変更。
- 開発用依存3件（Wrangler、Vitest、Workers types）をまとめた PR #38 が作成された。重複する個別 PR #34〜#36 は close 済み。本番用の Hono 更新 #37 は開いたまま。
- Rails 削除前の Bundler 更新 PR 10件と、削除済み CI アクションだけを更新する PR 3件を close 済み。現行 CI で使う checkout と setup-node の更新 PR は残した。

## 引き継ぎ

- PR #38 と #37 の変更内容と CI 結果を確認してからマージする。major 更新は個別に扱う。
