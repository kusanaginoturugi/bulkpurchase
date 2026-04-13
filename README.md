# 聖明王院道具一括注文システム

Rails 8 ベースの小規模向け注文集約アプリです。  
各伝道会の注文を月次サイクルで管理し、管理者が注文内容を確認できます。

## 技術構成

- Ruby 3.4.8
- Rails 8.0
- SQLite3
- Hotwire
- Tailwind CSS
- Solid Queue / Solid Cache / Solid Cable

## 開発環境

### mise

このリポジトリには `.mise.toml` を入れています。

```bash
mise install
mise use
```

`mise` を使わない場合は、Ruby `3.4.8` を手動で用意してください。

### セットアップ

```bash
bundle install
bin/rails db:prepare
bin/rails db:seed
bin/rails server
```

ポートを変える場合:

```bash
bin/rails server -p 3001
```

## 初期ログイン情報

`db/seeds.rb` で以下を作成します。

### 管理者

- email: `admin@example.com`
- password: `password`

### 一般ユーザー

- email: `member@example.com`
- password: `password`

## 動作確認資料

- 設計書: `DESIGN.md`
- 確認ガイド: `TEST_GUIDE.md`
- ブラウザ表示用ガイド: `/test_guide.html`

## EC2 Ubuntu 24.04 へのデプロイ

このアプリは SQLite のまま単一 EC2 上で動かす前提です。

### 1. OS パッケージ

```bash
sudo apt update
sudo apt install -y \
  build-essential \
  git \
  curl \
  pkg-config \
  libyaml-dev \
  zlib1g-dev \
  libffi-dev \
  libgmp-dev \
  libssl-dev \
  libsqlite3-dev \
  sqlite3
```

### 2. mise と Ruby を入れる

```bash
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
cd /path/to/bulkpurchase
mise install
```

`zsh` を使う場合:

```bash
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
source ~/.zshrc
```

### 3. アプリ配置

```bash
git clone <repository-url>
cd bulkpurchase
mise install
bundle install --deployment
```

### 4. master.key を配置

このリポジトリには `config/master.key` を含めていません。  
ローカルで生成された `config/master.key` を安全な方法でサーバに配置してください。

配置先:

```bash
config/master.key
```

または環境変数でも可:

```bash
RAILS_MASTER_KEY=...
```

### 5. production DB 準備

```bash
RAILS_ENV=production bundle exec rails db:prepare
RAILS_ENV=production bundle exec rails db:seed
```

SQLite ファイルは `storage/` 配下に作成されます。  
デプロイ時に `storage/` が消えないように運用してください。

### 6. アセット事前コンパイル

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

### 7. 起動

systemd 側は既存運用に合わせてください。  
アプリ側としては、少なくとも以下が通れば起動できます。

```bash
RAILS_ENV=production bundle exec puma -C config/puma.rb
```

## 本番運用時の注意

- SQLite を使うため、`storage/` の永続化が必要です
- `config/master.key` の安全な配布が必要です
- メール送信設定は未接続です
- `ApplicationMailer` の送信元は仮の `noreply@example.com` です
- `bin/dev` は本番向けではありません

## 反映確認コマンド

```bash
bundle exec rails zeitwerk:check
bundle exec rails routes
bundle exec rails db:prepare
```
