# 聖明王院道具一括注文システム 設計書

## 1. 文書概要

### 1.1 目的

聖明王院向けの道具注文を Web アプリ化し、各伝道会からの月次注文を集約して、管理者が寺へ送付する注文書 PDF を作成できるようにする。

### 1.2 参照資料

- `道具注文システム.odt`
- `items.csv`

### 1.3 この設計書で反映した修正点

元の `DESIGN.md` には実装時に曖昧になる点があったため、以下を修正した。

- 白陽八卦符の「願事差分」を `notes` の自由記入だけにせず、PDF 集計に使える区分として扱う方針に変更
- `items.csv` に存在しない「護摩センター区分」「単位」の管理方法を追加
- 伝道会を「ログインユーザー所属で固定」とする理由を明文化
- 同一月の注文の扱い、締切後の扱い、PDF 作成後の状態遷移を追加
- 実装前提として不足していた管理機能と初期データ投入方針を追加

## 2. 要件整理

### 2.1 業務要件

- 各ユーザーはログインして所属伝道会の注文を登録する
- 注文対象は道具マスタから選択する
- マスタにない道具は自由入力できる
- 注文時に必要なのは主に「道具名」「数量」「備考」であり、金額は画面表示しない
- 毎月の注文サイクルごとに締切、注文日、必着日、月例番号を管理する
- 管理者は月次注文を伝道会別に集計し、寺へ送る PDF を出力できる
- 注文登録後に注文者へ確認メールを送る
- 注文日の前日にリマインドメールを送る
- 注文日に管理者向け PDF を送る

### 2.2 画面要件

- 一般ユーザー
  - ログイン
  - 注文入力
  - 注文修正
  - 注文確認
  - 注文履歴
- 管理者
  - 注文サイクル管理
  - 伝道会管理
  - ユーザー管理
  - 道具マスタ管理
  - 注文一覧 / 集計確認

## 3. 設計方針

### 3.1 技術スタック

| 項目 | 選択 |
|------|------|
| フレームワーク | Ruby on Rails 8 系 |
| DB | SQLite3 |
| 認証 | Rails 標準認証ジェネレーター |
| 非同期ジョブ | Solid Queue |
| スケジュール | recurring task |
| フロントエンド | Hotwire (Turbo + Stimulus) |
| CSS | Tailwind CSS |
| PDF 生成 | Prawn |

補足:

- 現時点では小規模運用前提のため SQLite3 を採用する
- 本番で同時利用やバックアップ要件が強くなった場合は PostgreSQL へ移行可能な設計とする

### 3.2 UI/運用上の判断

- 伝道会は注文時にプルダウン選択ではなく、ログインユーザーの所属伝道会で固定する
  - 理由: 誤注文防止のため
  - 画面上は表示のみとし、ユーザーによる変更は不可
  - 元資料の「プルダウン」は紙画面イメージと解釈し、Web では所属固定の方が安全
- 1 つの注文サイクルに対して、各ユーザーは 1 件の注文を提出する
- 提出前は下書き保存可能、提出後も管理者が寺へ注文送信するまでは再編集可能とする
- `order_cycle.status = sent` になった時点で一般ユーザーから編集不可
- 管理者は送信後も内容確認できる

## 4. 業務ルール

### 4.1 注文サイクル

- 注文サイクルは年月単位で管理する
- 同一年同月のサイクルは 1 件のみ作成可能
- 管理者は以下を設定する
  - 月例番号
  - 締切日時
  - 注文日
  - 必着日
- 締切日時は画面表示と運用上の目安として使うが、一般ユーザーの編集可否は `sent` 状態で判定する
- 状態は以下で管理する
  - `open`: 受付中
  - `closed`: 締切済み
  - `sent`: PDF 作成・送信済み

### 4.2 注文

- ログイン中ユーザーの所属伝道会の注文として登録する
- 注文ヘッダには以下を保持する
  - 注文者名
  - 持ち帰り者名
  - 所属伝道会
  - 対象注文サイクル
- 同一サイクルに対する同一ユーザーの注文は 1 件とし、再編集時は既存注文を更新する
- 一般ユーザーは対象サイクルが `sent` になるまで注文を修正できる
- 注文状態は以下で管理する
  - `draft`: 下書き
  - `submitted`: 提出済み
- `submitted` へ遷移したタイミングで確認メールを送信する

### 4.3 道具入力

- 基本は道具コード検索でマスタから選択する
- マスタ未登録道具は自由入力行で登録する
- 金額情報は DB に保持してよいが、一般ユーザー画面には表示しない
- 数量は整数のみ
- 単位は行ごとに保持する

### 4.4 特殊な道具

元資料では、単純な「道具名 + 数量」だけでは PDF 集計が不足するものがある。

#### 白陽八卦符

元資料の PDF 例では以下のように願事別に別行集計している。

- 白陽八卦符(無地)
- 白陽八卦符(有気復命)

このため、`notes` 自由入力だけでは集計不能になる。  
本システムでは、白陽八卦符を選択した場合は「種別」を別項目として入力させ、PDF 集計キーに含める。

候補:

- 無地
- 有気復命
- その他自由入力

#### 組単位の道具

以下は数量入力時の単位を自動で `組` にする。

- みろく鵺符
- 白陽八卦符

### 4.5 PDF 集計ルール

- 集計軸は「出力名 × 伝道会」
- 出力名は以下で決定する
  - 通常道具: `item_name`
  - 白陽八卦符: `item_name + '(' + variant_name + ')'`
  - 自由入力: 入力された道具名
- 数量は伝道会別に合計する
- 合計列を表示する
- 単位は出力名ごとに付与する

## 5. マスタ管理方針

### 5.1 items.csv の扱い

`items.csv` には以下のみが含まれる。

- `code`
- `name`
- `value`
- `refund`

一方、業務上必要な以下は CSV に存在しない。

- 護摩センター区分
- 単位
- 有効 / 無効
- 特殊入力要否

そのため、CSV は初期取り込み元とし、不足項目は DB 上で管理する。

### 5.2 護摩センター区分

元資料には「護摩センター 1,2 を引っ張ってきたい」とあるため、道具マスタに区分を持たせる。

- `center_category`: `center_1`, `center_2`, `other`

運用:

- 初回取り込み後、管理者が必要な道具に区分を設定する
- 注文画面では通常 `center_1`, `center_2` の有効道具を検索対象とする
- 必要に応じて自由入力を許可する

## 6. データモデル

### 6.1 organizations

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| name | string | 伝道会名 |
| active | boolean | 利用可否 |
| created_at | datetime | |
| updated_at | datetime | |

### 6.2 users

Rails 標準認証に準拠し、業務項目を追加する。

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| name | string | 氏名 |
| email_address | string | ログインID兼通知先 |
| password_digest | string | 認証用 |
| organization_id | integer | 所属伝道会 |
| role | string | `user` / `admin` |
| active | boolean | 利用可否 |
| created_at | datetime | |
| updated_at | datetime | |

### 6.3 items

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| code | string | 道具コード |
| name | string | 道具名 |
| value | integer | 売価 |
| refund | integer | 還付額 |
| unit | string | 本 / 枚 / 組 など |
| center_category | string | `center_1` / `center_2` / `other` |
| special_handling_type | string | `none` / `hakuyo_hakke` |
| active | boolean | 利用可否 |
| created_at | datetime | |
| updated_at | datetime | |

補足:

- `unit` は CSV からは得られないため管理画面で設定する
- 白陽八卦符は `special_handling_type = 'hakuyo_hakke'` とする

### 6.4 item_variants

PDF 集計や入力補助のための道具内訳マスタ。

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| item_id | integer | 対象道具 |
| name | string | 無地 / 有気復命 など |
| display_order | integer | 並び順 |
| active | boolean | 利用可否 |
| created_at | datetime | |
| updated_at | datetime | |

用途:

- 白陽八卦符のように同一道具コードでも出力行を分けたいケースに対応する

### 6.5 order_cycles

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| year | integer | 年 |
| month | integer | 月 |
| cycle_number | integer | 月例番号 |
| deadline_at | datetime | 締切日時 |
| order_date | date | 寺への注文日 |
| arrival_date | date | 必着日 |
| status | string | `open` / `closed` / `sent` |
| created_at | datetime | |
| updated_at | datetime | |

制約:

- `year + month` は一意

### 6.6 orders

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| user_id | integer | 注文者ログインユーザー |
| organization_id | integer | 所属伝道会 |
| order_cycle_id | integer | 対象サイクル |
| orderer_name | string | 注文者名 |
| pickup_name | string | 持ち帰り者名 |
| status | string | `draft` / `submitted` |
| submitted_at | datetime | 提出日時 |
| created_at | datetime | |
| updated_at | datetime | |

制約:

- `user_id + order_cycle_id` は一意

### 6.7 order_items

| カラム | 型 | 説明 |
|--------|----|------|
| id | integer | PK |
| order_id | integer | 親注文 |
| item_id | integer | マスタ道具。自由入力時は NULL |
| item_variant_id | integer | 道具内訳。不要時は NULL |
| item_code | string | スナップショット |
| item_name | string | スナップショット |
| variant_name | string | スナップショット |
| quantity | integer | 数量 |
| unit | string | 単位 |
| notes | text | 備考 |
| sort_order | integer | 画面並び順 |
| created_at | datetime | |
| updated_at | datetime | |

設計意図:

- 注文時点の表示値を保持し、後でマスタ変更されても過去注文を壊さない
- PDF は `item_name` / `variant_name` / `unit` を使って出力する

## 7. バリデーション

### 7.1 users

- `name`, `email_address`, `organization_id`, `role` 必須

### 7.2 items

- `code`, `name` 必須
- `code` は一意
- `unit` は運用上必須

### 7.3 order_cycles

- `year`, `month`, `cycle_number`, `deadline_at`, `order_date`, `arrival_date` 必須
- `year + month` 一意
- `deadline_at <= order_date.end_of_day`

### 7.4 orders

- `orderer_name`, `pickup_name`, `organization_id`, `order_cycle_id` 必須
- 提出時は明細 1 行以上必須

### 7.5 order_items

- `item_name`, `quantity`, `unit` 必須
- `quantity` は 1 以上の整数
- 白陽八卦符の場合は `variant_name` 必須

## 8. 画面設計

### 8.1 ログイン

- Rails 標準認証画面を利用する

### 8.2 注文入力

表示項目:

- 対象月
- 月例番号
- 締切日時
- 伝道会名
- 注文者名
- 持ち帰り者名
- 注文明細行

補足:

- 伝道会名はログインユーザーの所属情報を表示のみ行う
- ユーザーは伝道会を変更できない

明細入力仕様:

- 道具コードまたは名称で検索
- 候補選択時に道具名、単位、内部 ID を設定
- 白陽八卦符選択時は種別入力欄を表示
- 行追加 / 行削除可能
- 自由入力行を追加可能

### 8.3 注文修正

- 登録済みまたは提出済みの注文を再編集する画面
- 入力項目は注文入力画面と同一
- `order_cycle.status != sent` の間は修正可能
- `sent` 後は参照のみ

### 8.4 注文確認

- 提出済み内容を表示
- `order_cycle.status != sent` の間のみ編集導線を表示

### 8.5 注文履歴

- 過去サイクルの注文一覧
- 直近注文を新規作成時の参考として閲覧可能

### 8.6 管理画面

- 注文サイクル管理
- 伝道会管理
- ユーザー管理
- 道具マスタ管理
- 注文一覧
- PDF 生成 / 再送

## 9. ルーティング案

```ruby
resource  :session
resources :passwords, param: :token

resource :current_order, only: [:show, :create, :update], controller: :current_orders
resources :orders, only: [:index, :show]

resources :items, only: [] do
  collection do
    get :search
  end
end

namespace :admin do
  root to: "order_cycles#index"

  resources :organizations
  resources :users
  resources :items
  resources :item_variants
  resources :order_cycles do
    member do
      post :close
      post :send_summary
    end
  end
  resources :orders, only: [:index, :show]
end

root "current_orders#show"
```

補足:

- 一般ユーザーは「現在受付中サイクルの注文」を編集するため、`current_order` の方が自然
- controller は `CurrentOrdersController` とし、単数 resource を割り当てる

## 10. メール / ジョブ設計

### 10.1 メール

- `OrderMailer.confirmation(order)`
  - 注文提出時に注文者へ送信
- `OrderMailer.reminder(order)`
  - 注文日前日に提出済みユーザーへ送信
- `OrderMailer.summary(order_cycle, pdf)`
  - 注文日に管理者へ PDF 添付送信

### 10.2 定期ジョブ

`DailyOrderCheckJob` を日次実行する。

処理:

1. 注文日が翌日の `order_cycle` を取得
2. 対象サイクルの提出済み注文に対してリマインド送信
3. 注文日が当日の `order_cycle` を取得
4. PDF を生成して管理者へ送信
5. `order_cycle.status` を `sent` に更新

### 10.3 冪等性

日次ジョブの二重送信を防ぐため、以下のいずれかを実装する。

- 送信日時カラムを別途持つ
- 送信対象ジョブ実行ログを持つ

最低限、`sent` 状態サイクルは自動再送しない。

## 11. PDF 設計

### 11.1 ヘッダ

- タイトル: `聖明王院道具一括注文`
- 必着日
- 注文日
- 注文者名または作成者名

### 11.2 本文

表形式で以下を表示する。

- 左列: 出力名
- 中央列群: 各伝道会の数量
- 右列: 合計

例:

```text
道具名                  | 富士山 | 山梨 | 大仏殿 | 合計
収天・灶君護摩木        | 1000本 | 1000本 | 2000本 | 4000本
白陽八卦符(無地)        | 30組   | 50組   | 100組  | 180組
白陽八卦符(有気復命)    | 10組   | 10組   | 0組    | 20組
```

### 11.3 並び順

初期仕様では以下の順で出力する。

1. 道具コード順
2. 同一道具内では variant の表示順
3. 自由入力行は末尾

## 12. 初期データ / 運用

### 12.1 seeds

- `items.csv` から道具を初期投入
- 組単位対象の単位設定
- 白陽八卦符用の variant 初期投入

### 12.2 管理者の初期作業

- 管理者ユーザー作成
- 伝道会登録
- 一般ユーザー登録
- 道具マスタの単位設定
- 護摩センター区分設定
- 必要に応じて variant 登録

## 13. 今回のスコープ

### 13.1 対象

- ログイン認証
- 注文サイクル管理
- 注文入力 / 編集 / 閲覧
- 道具マスタ検索
- 自由入力行
- PDF 出力
- メール送信
- 管理画面の基本 CRUD

### 13.2 対象外

- 決済
- 外部会計連携
- スマホアプリ化
- 複数寺院対応

## 14. 要確認事項

以下は実装前に確認したいが、未確認でもこの設計で着手は可能。

- リマインドメールの送信対象は「提出済みユーザー」で正しいか
  - 未提出者への督促が必要なら仕様を変えるべき
- PDF の「注文者名」は代表 1 名を出すのか、管理者名を出すのか
- 護摩センター区分 1 / 2 の正式な初期対応表があるか
- 白陽八卦符以外にも variant 管理が必要な道具があるか
