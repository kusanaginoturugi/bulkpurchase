# 依存更新の運用

## 計画

- Dependabot の更新確認を週1回にする。
- Worker の開発用と本番用の minor・patch 更新を、それぞれ1本の PR にまとめる。
- major 更新とセキュリティ更新は個別に確認する。

## 2026-10-13 作業記録

- `.github/dependabot.yml` に npm の2グループと GitHub Actions の minor・patch グループを設定。
- 更新確認の頻度を daily から weekly に変更。
- 開発用依存3件（Wrangler、Vitest、Workers types）をまとめた PR #38 が作成された。重複する個別 PR #34〜#36 は close 済み。本番用の Hono 更新 #37 は開いたまま。
- Rails 削除前の Bundler 更新 PR 10件と、旧 Rails CI を対象にした Actions 更新 PR 4件を close 済み。#25 も差分が旧 Rails CI を対象にしていたため、追加で close した。現行 CI を対象にした setup-node 更新 #33 は残した。

## 引き継ぎ

- PR #38・#37・#33 は個別の CI が成功している。#38 と #37 はどちらも `worker/package-lock.json` を変更するため、順にマージし、後の PR の競合と CI を再確認する。#33 は major 更新として個別に確認する。
