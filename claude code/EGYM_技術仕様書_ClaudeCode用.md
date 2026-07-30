# EGYM マスタートレーナー制度 — 完全技術仕様書
## （Claude Code 向け引き継ぎドキュメント）

> ⚠️ **作業対象フォルダ（正: canonical）は `…/マスター制度/file6/`。** file1〜file5 は6月の旧版で編集禁止。
> 最新の HTML / SQL / Edge Function はすべて `file6` にある。本仕様書はその原本ドキュメント。
> 日々の変更履歴は `file6/WORK_LOG_YYYY-MM-DD.md`、オーナー向け導入手順は `file6/SETUP_CHECKLIST.md` を参照。

---

## 1. プロジェクト概要

**プロジェクト名:** EGYM マスタートレーナー認定制度  
**クライアント:** Johnson Health Tech Japan（JHTJapan）  
**目的:** EGYMジムトレーナーを3段階（Star1/Star2/Star3）で認定・管理するWebアプリケーション  
**開発状況:** 全6画面が Supabase 接続済み。育成→認定ハンドシェイクを実データで実装済み。実機E2Eテストとセキュリティ（RLS）厳格化が残タスク。  
**担当者:** 非エンジニア（操作はGitHubへのファイルアップロードのみ）

---

## 2. インフラ構成

### GitHub
- **リポジトリ:** `Jht-japan/egym-master`
- **ブランチ:** `main`
- **デプロイ方法:** GitHubにHTMLファイルをアップロード → Vercelが自動デプロイ

### Vercel
- **URL:** `https://egym-master.vercel.app/`
- **プラン:** 無料（Hobby）
- **デプロイ:** GitHub mainブランチへのpushで自動デプロイ

### Supabase
- **プロジェクト名:** Jht EGYM Trainer
- **Project URL:** `https://gcqqhjeqvnfbgdenflmk.supabase.co`
- **Publishable Key:** `sb_publishable_P9Ze3fOsCIpuhzx4AYednA_Gbxf9OO1`
- **Service Role Key:** Supabase Secretsに `SERVICE_ROLE_KEY` として保存済み（HTMLには記載しない）
- **Auth Provider:** Email/Password のみ
- **Site URL:** `https://egym-master.vercel.app`
- **Redirect URL:** `https://egym-master.vercel.app/login.html`

---

## 3. ファイル構成

```
file6/                              # ← 正フォルダ（canonical）
├── login.html                  # ログイン画面（全ユーザー共通・Supabase接続済み）
├── egym_super_account.html     # JHTJapan最高管理者画面（Supabase接続済み）
├── egym_facility_app.html      # 施設管理者画面（Supabase接続済み）
├── egym_star1_app.html         # Star1トレーナー画面（Supabase接続済み）
├── egym_star2_final.html       # Star2トレーナー画面（Supabase接続済み）
├── egym_star3_app.html         # Star3トレーナー画面（Supabase接続済み）
├── SETUP_CHECKLIST.md          # オーナー向けセットアップ手順（EN/JA）
├── WORK_LOG_2026-07-29.md      # 作業ログ / 引き継ぎ
└── supabase/
    ├── create-trainer-progress.sql      # trainer_progress テーブル作成
    ├── fix-facility-delete-cascade.sql  # 施設削除FKエラーの修正
    ├── tighten-rls.sql                  # RLS厳格化（本番前に適用）
    └── functions/grade-test/index.ts    # AI採点 Edge Function
```

**技術スタック:**
- 純粋なHTML/CSS/JavaScript（フレームワークなし）
- Supabase JS SDK（CDN経由）: `https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2`
- Tabler Icons（CDN経由）
- Google Fonts（Noto Sans JP）
- Claude API（Star2アプリのAIテスト採点機能。Edge Function `grade-test` 経由）

---

## 4. Supabaseデータベース構成

### テーブル一覧

#### `facilities`（施設）
```sql
id          uuid  primary key default gen_random_uuid()
name        text  not null
region      text
admin_email text
status      text  default 'active'
created_at  timestamptz default now()
```

#### `trainers`（トレーナー）
```sql
id          uuid  primary key default gen_random_uuid()
facility_id uuid  references facilities(id)
name        text  not null
email       text
star_level  text  -- 'star1', 'star2', 'star3'
status      text  default 'active'  -- 'active', 'certified'
cl_pct      int   default 0  -- チェックリスト進捗（0-100）
cert_date   text  -- 認定日
mentored_by uuid  references trainers(id)  -- 担当メンターのID
prog1_done  boolean default false
prog2_done  boolean default false
created_at  timestamptz default now()
```

#### `user_roles`（権限管理）
```sql
id          uuid  primary key default gen_random_uuid()
user_id     uuid  references auth.users(id)
role        text  -- 'super', 'facility', 'star1', 'star2', 'star3'
facility_id uuid  references facilities(id)
created_at  timestamptz default now()
-- UNIQUE INDEX: (user_id, role) -- 同じroleの重複は防ぐが複数roleは許可
```

#### `test_results`（テスト結果）
```sql
id          uuid  primary key default gen_random_uuid()
trainer_id  uuid  references trainers(id)
score       int
passed      boolean
created_at  timestamptz default now()
```

#### `cert_requests`（認定申請）
```sql
id          uuid  primary key default gen_random_uuid()
trainer_id  uuid  references trainers(id)
facility_id uuid  references facilities(id)
status      text  default 'pending'
created_at  timestamptz default now()
```

#### `invitations`（招待履歴）
```sql
id          uuid  primary key default gen_random_uuid()
email       text
role        text
facility_id uuid
created_at  timestamptz default now()
```

#### `trainer_progress`（トレーナー進捗・クラウド同期）
```sql
-- トレーナー1人 = 1行。進捗を JSON で保持（Star1/2/3アプリのクラウド保存に使用）
trainer_id  uuid  references trainers(id)   -- 1トレーナー1行
checklist   jsonb  -- チェックリスト進捗
programs    jsonb  -- プログラム①②進捗
ba_data     jsonb  -- Star3のB/A記録（お客様2名 × Before/Mid/After）
test        jsonb  -- AIテストの点数・状態（点数は test_results ではなくここに保持）
notes       jsonb  -- メモ
updated_at  timestamptz default now()
```
> 作成SQL: `file6/supabase/create-trainer-progress.sql`（SETUP_CHECKLIST step1 で実行）。
> ⚠️ **候補者データはここには持たない。** 候補者は `trainers` テーブルから `mentored_by=自分` で取得する（下記7章）。

### RLSポリシー（現在はテスト用の全許可設定）
```sql
-- facilities: 全許可（テスト用）
create policy "allow_all_facilities" on facilities for all using (true) with check (true);

-- trainers: 全許可（テスト用）
create policy "allow_all_trainers" on trainers for all using (true) with check (true);

-- user_roles: 自分のroleのみ読める
create policy "allow_read_own_role" on user_roles for select using (auth.uid() = user_id);
```

> ⚠️ **本番移行前にRLSポリシーを各ロールに応じて厳格化が必要**

---

## 5. Edge Function仕様

Edge Function は2つ: `bright-endpoint`（ユーザー/ロール管理）と `grade-test`（AI採点）。

### 5-1. `bright-endpoint`（ユーザー・ロール管理）

**URL:** `https://gcqqhjeqvnfbgdenflmk.supabase.co/functions/v1/bright-endpoint`  
**Secret:** `SERVICE_ROLE_KEY`（Supabase Secretsに保存済み）

### 対応アクション

#### `invite`（新規招待 / 既存ユーザーへのrole追加）
```json
{
  "action": "invite",
  "email": "trainer@example.com",
  "name": "田中 太郎",
  "role": "star1",
  "facilityId": "uuid-of-facility"
}
```
- 既存メールアドレスの場合: 新規アカウントを作らず、既存アカウントに新しいroleをinsert
- 新規メールアドレスの場合: `inviteUserByEmail`でアカウント作成 + 招待メール送信
- redirectTo: `https://egym-master.vercel.app/login.html`

#### `delete_user`（ログインアカウント完全削除）
```json
{
  "action": "delete_user",
  "email": "trainer@example.com"
}
```
- `user_roles`から全role削除 → `auth.users`から削除

#### `promote_role`（昇格: 同一アカウントのままrole変更）
```json
{
  "action": "promote_role",
  "email": "trainer@example.com",
  "fromRole": "star1",
  "toRole": "star2"
}
```
- 新規アカウントは作らない
- `user_roles`の該当行のroleを更新するだけ

#### `remove_facility_role`（施設削除時: その施設に紐づくroleだけ削除）
```json
{
  "action": "remove_facility_role",
  "email": "trainer@example.com",
  "facilityId": "uuid-of-facility"
}
```
- その施設に紐づくroleのみ削除
- 他にroleが残っていればアカウント維持
- 何もroleが残らない場合のみアカウント削除

### 5-2. `grade-test`（AIテスト採点）

**URL:** `https://gcqqhjeqvnfbgdenflmk.supabase.co/functions/v1/grade-test`  
**Secret:** `ANTHROPIC_API_KEY`（Supabase Secretsに `sk-ant-...` として登録が必要）  
**ソース:** `file6/supabase/functions/grade-test/index.ts`

- Star2アプリのAIテスト採点で使用。Claude API をクライアントから直接叩かず、この Edge Function 経由で呼ぶ。
- デプロイ手順は SETUP_CHECKLIST step3。設定は `bright-endpoint` と同じでよい。
- ⚠️ 旧バージョン（`{prompt}` を受け取る版）をデプロイ済みの場合は、最新 `index.ts` で**再デプロイ必須**（入力形式が変更されている）。
- 採点結果は `trainer_progress.test`（JSON）に保存される（`test_results` テーブルは現状未使用）。

---

## 6. 権限・認証フロー

### ログインフロー
```
login.html
  ↓ signInWithPassword
  ↓ user_rolesを全取得（.eq('user_id', userId)）
  ↓ roleが1つ → 自動遷移
  ↓ roleが複数 → 「どちらの画面を開きますか？」選択画面
```

### ロールと遷移先
```javascript
const ROLE_PAGES = {
  'super':    'egym_super_account.html',
  'facility': 'egym_facility_app.html',
  'star1':    'egym_star1_app.html',
  'star2':    'egym_star2_final.html',
  'star3':    'egym_star3_app.html',
};
```

### セッション情報（sessionStorage）
```javascript
egym_user_id       // Supabase auth user id
egym_user_email    // メールアドレス
egym_role          // 現在選択中のrole
egym_facility_id   // 施設ID（facility/star系の場合）
```

### 権限階層
```
JHTJapan（super）
  → 施設作成・施設管理者招待・全トレーナー操作可能

施設管理者（facility）
  → 自施設のStar1/2/3招待・認定申請承認

Star3
  → Star2候補者のみ招待可能

Star2
  → Star1候補者のみ招待可能

Star1
  → 招待権限なし
```

---

## 7. 認定ルール（ビジネスロジック）

### Star1の認定条件
- チェックリスト100%完了
- ベーシックプログラム完了
- → Star2が「認定する」ボタンで認定

### Star2の認定条件
- チェックリスト100%完了
- プログラム①②完了
- AIテスト80点以上合格
- **Star1を2名以上育成・認定済み**
- → 施設管理者へ申請 → JHTJapanへ通知

### Star3の認定条件
- チェックリスト100%完了
- プログラム①②完了
- **Star2を2名以上育成・認定済み**
- **お客様2名のB/Aデータ作成（Before・Mid・After全フェーズ全項目入力）**
- テスト合格
- → JHTJapanが最終認定

### 育成・メンタリングルール
- 1人のトレーナーは1人のメンターにのみ紐付く（JS側でチェック）
- Star2がStar1を育成（1対多可）
- Star3がStar2を育成（1対多可）
- 昇格（Star1→Star2等）時は新規アカウントを作らず、同一アカウントのままroleを変更

### 認定ハンドシェイク（誰が誰を認定するか）★実装済み
データモデル: **候補者 = `trainers` テーブルで `mentored_by=自分のtrainer id` かつ該当 `star_level` の行**。
認定 = その候補者の `trainers.status='certified'`, `cert_date=今日` を書き込む（ダミーデータは全廃）。

```
Star1本人: チェックリスト100% + ベーシックPG完了 → cl_pct/prog1_done が trainers に同期
   ↓（Star2が「スター1育成」タブで実進捗を確認）
Star2 が Star1 を直接認定（「スター1認定」ボタン）→ Star1.status='certified'
   ↓（Star1アプリは status を見て「認定されました」を表示）
Star2本人: チェックリスト + PG①② + AIテスト80点 + 認定済Star1が2名 → 施設へ cert_requests 申請
   ↓
施設管理者 が承認 → Star2.status='certified'   ※Star3はStar2を認定しない＝監視のみ
   ↓（Star3は「スター2育成」タブで監視。2名認定でゲート達成）
Star3本人: チェックリスト + 認定済Star2が2名 + B/Aデータ2名分 → JHTJapanへ申請 → super が最終認定
```

- **Star1 → Star2 が直接認定**
- **Star2 → 施設管理者が承認**（cert_requests）。→ **Star3 は Star2 を認定しない（監視のみ）**
- **Star3 → super（JHTJapan）が最終認定**

---

## 8. 複数ロール対応

施設管理者が同時にStar1/2/3トレーナーを兼任できる。

```
同じメールアドレス → 1つのログインアカウント
                  → user_rolesに複数行
                  例:
                    row1: role=facility, facility_id=A施設
                    row2: role=star1,    facility_id=A施設
```

ログイン時に複数roleを検出 → 画面選択UIを表示。

---

## 9. 安全対策

### PROTECTED_EMAILS（スーパーアカウント保護）
`egym_super_account.html`内に以下を定義:
```javascript
var PROTECTED_EMAILS = ['maskey@jhtgroup.jp'];
```
このメールアドレスは施設削除・トレーナー削除処理で絶対に削除されない。

### スーパーアカウント情報
- **Email:** `maskey@jhtgroup.jp`
- **Role:** `super`
- **facility_id:** null
- ⚠️ テストでこのメールを施設管理者として使わないこと

---

## 10. 実装済み機能一覧

### login.html ✅
- メール+パスワードログイン
- 複数role対応（選択画面表示）
- パスワード表示ボタン（目のアイコン）
- パスワードリセット機能（Supabase `resetPasswordForEmail`）
- 既存セッション検出で自動遷移（**egym_user_id/email を sessionStorage に保存**・監査#5修正済み 2026-07-30）
- **パスワード設定画面**（2026-07-30 追加）: 招待受諾リンク／パスワード再設定リンクは URL hash が
  `type=invite|recovery` で戻るため、これを検知して「パスワード設定」フォームを表示 → `auth.updateUser({password})`
  → role に応じて遷移。招待ユーザーが初回パスワードを設定できるようになった（再設定リンクも同画面で機能）。

### egym_super_account.html ✅（Supabase接続済み）
- 施設一覧・詳細表示（Supabaseから読み込み）
- 施設追加（Supabase insert + Edge Function invite）
- 施設削除（トレーナー+user_roles削除 → 施設削除）
- トレーナー追加（Supabase insert + Edge Function invite）
- トレーナー削除（ログインアカウントも削除）
- 育成関係表示（Star3→Star2→Star1のツリー表示）
- 育成対象割り当て・解除（mentoredByフィールド更新）
- 昇格機能（認定済みStar1→Star2等、同一アカウントでrole変更）
- 認定状況サマリー表示
- PROTECTED_EMAILS安全ガード
- 施設削除の外部キー制約エラー → `fix-facility-delete-cascade.sql` で解消（SETUP_CHECKLIST step2）

### egym_facility_app.html ✅（Supabase接続済み）
- 施設情報表示
- 自施設のトレーナー一覧
- トレーナー招待
- 認定申請（cert_requests）の承認 / 却下 → Star2.status='certified' を書き込み

### egym_star1_app.html ✅（Supabase接続済み）
- チェックリスト機能（`trainer_progress` にクラウド保存）
- プログラム進捗管理（cl_pct / prog1_done を trainers に同期）
- 認定状況表示: 実データ `SELF.status==='certified'` を参照（3状態: 認定済み / 全条件達成でStar2の認定待ち / 未達）
- 認定申請モーダル: 担当スター2名を実データ表示
- `refreshStatus()`（「状態を更新」ボタン）で status/cert_date を再取得
- メモ機能

### egym_star2_final.html ✅（Supabase接続済み）
- チェックリスト機能（クラウド保存）
- プログラム①②進捗管理
- AIテスト機能（Edge Function `grade-test` で採点、5日タイマー）
- 候補者（Star1）管理: **実データ**（`mentored_by=自分` かつ `star_level='star1'`）。ダミーデータは廃止
- Star1招待（`doInvite`: trainers insert + Edge invite）／ Star1認定（`doCertify`: status='certified'）
- 認定状況表示（認定済Star1が2名で申請可能・実status基準）
- メモ機能

### egym_star3_app.html ✅（Supabase接続済み）
- チェックリスト機能（クラウド保存）
- プログラム①②進捗管理
- B/A記録（お客様2名 × Before/Mid/After × 7項目）
- 候補者（Star2）管理: **実データ・閲覧のみ**（Star2の認定は施設管理者が実施）。ダミーデータは廃止
- Star2招待（`doInvite`: trainers insert + Edge invite）
- 認定状況表示（認定済Star2が2名 + B/Aデータ完了で申請可能・実status基準）
- メモ機能

> 🔴 **Fix #1（保存の不具合・2026-07-29修正済み）:** Star2/Star3 は `serializeProgress()` が
> `trainer_progress` に存在しない `candidates` 列を送っていたため保存が毎回失敗（PGRST204）していた。
> 候補者を trainers 実データから読む方式に変え、`candidates` を serialize/hydrate から削除して解消。

### 共通機能: ログアウト ✅（2026-07-30 追加）
- **全5画面**（super / facility / star1 / star2 / star3）のトップバー右上に「ログアウト」ボタンを追加。
- 共通関数 `egymLogout()`: `_sb.auth.signOut()` → `sessionStorage.clear()` → `login.html` へ `location.replace`。
- 追加理由: これまで**どの画面にもログアウトが無く**、テスト時にユーザーを切り替えられなかったため。

---

## 11. 既知の問題・未解決事項

### 🔴 優先度: 高（翌日ここから — 判断事項）

#### 判断①: RLS厳格化後の書き込み経路
- 認定・招待は現在**クライアントから直接 `trainers` を書き込む**（super の insert / facility の approveCert と同じパターン）。
- `tighten-rls.sql` を適用すると `trainers` への書き込みがロール制限され、**認定/招待が失敗する可能性**。
- 選択肢: **(A)** 書き込みを Edge Function（service role）経由に移す（安全・推奨、実装量あり）／ **(B)** `tighten-rls.sql` 側で該当ロールに UPDATE/INSERT を許可。
- **方針:** まず allow-all で全機能テスト → その後どちらで恒久対応するか決定。

#### 判断②: Star3 は Star2 を「直接認定」するか？ → ✅ 決定済み（2026-07-30）
- **決定: 「監視のみ」で確定。Star3 は Star2 を直接認定しない**（Star2認定は施設管理者が実施）。
- 現状のコードがこの仕様どおりのため、**追加のコード変更は不要**。

### 🟡 優先度: 中

#### 実機E2Eテストが未実施
- 構文バランスは検証済みだが、ログインを伴う実機テストは未実施（パスワード入力不可のため）。
- オーナーが `SETUP_CHECKLIST.md` の手順（特に step5 の育成ハンドシェイク）で実施予定。

#### メール送信回数制限
- Supabaseデフォルトのメール送信は時間あたりの制限あり（`email rate limit exceeded`）
- 本番運用前にResend等の外部SMTPを設定する必要あり

#### RLSポリシーが緩すぎる
- 現在は全許可ポリシー（テスト用）。`tighten-rls.sql` を用意済みだが未適用（判断①参照）
- 本番前に各ロールに応じた適切なポリシーへ変更が必要

### 🟢 優先度: 低

- **`test_results` テーブル未使用:** AI点数は `trainer_progress.test`（JSON）にのみ保持。DB正規化するなら要検討。
- **Star3 の確認テスト**が「準備中」表示のまま（仕様未確定）。
- **招待メールの送信元:** 現状 Supabase 標準送信（送信制限あり）。本番前に Resend 等のSMTP設定が必要。

> ✅ **解消済み（2026-07-30）監査#5:** login.html の既存セッション自動遷移で `egym_user_id`/`egym_user_email`
> を sessionStorage に保存するよう修正。**招待受諾時の「読み込みエラー」**（トレーナー画面が email を取得できず
> `ログイン情報が見つかりません`）を解消。あわせて招待/再設定リンク用の「パスワード設定」画面を追加（§10 login.html）。

> ✅ **解消済み:** 施設削除時の外部キー制約エラー（`user_roles_facility_id_fkey`）は
> `file6/supabase/fix-facility-delete-cascade.sql` で修正（SETUP_CHECKLIST step2 で実行）。
> ✅ **解消済み:** Star1/2/3・施設アプリの Supabase 未接続 → 全画面接続済み（10章）。

---

## 12. 次のステップ（優先順位）

1. **オーナーが実機テスト**（`SETUP_CHECKLIST.md` step1〜5）→ クラウド保存＆育成ハンドシェイクの動作確認。
2. **判断①（RLS書き込み経路）** を決めて恒久対応（Edge Function経由 or ポリシー緩和）。
3. **判断②（Star3直接認定の要否）** をオーナーに確認。
4. **RLSポリシー厳格化**（`tighten-rls.sql` 適用・SETUP_CHECKLIST step6）→ ロール別に再テスト。
5. 動作OKなら file6 の HTML を GitHub にアップロード → Vercel 反映（SETUP_CHECKLIST step4）。
6. （任意）login.html の sessionStorage 保存漏れ修正、`test_results` 連携。
7. **SMTP設定**（Resend等）でメール送信制限を解消（本番前）。
8. **カスタムドメイン設定**（会社ドメイン取得後）。

---

## 13. よく使うSQL

```sql
-- 全ユーザーとロールを確認
select ur.user_id, ur.role, ur.facility_id, f.name as facility_name
from user_roles ur
left join facilities f on f.id = ur.facility_id;

-- 施設とトレーナー一覧
select f.name as facility, t.name as trainer, t.star_level, t.status
from trainers t
join facilities f on f.id = t.facility_id;

-- 特定施設のuser_rolesを確認
select * from user_roles where facility_id = '施設のUUID';

-- user_rolesを手動でsuperに設定
insert into user_roles (user_id, role, facility_id)
values ('ユーザーのUUID', 'super', null);

-- 施設のステータスカラム追加（過去に実行済み）
alter table facilities add column if not exists status text default 'active';
```

---

## 14. コード規約・スタイル

- 全ファイル単一HTMLファイル（HTML+CSS+JS in one file）
- CSSは`<style>`タグ内にCSS変数で定義
- JavaScriptは`var`使用（一部`const`/`let`/arrow function）
- Supabaseクライアント: `const _sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY)`
- ルーティング: `go('page-name')` 関数でSPA的に画面切り替え
- レンダリング: `render()` → 各`r*()`関数が文字列のHTMLを返す → `innerHTML`で注入
- モーダル: `ST.modal = 'modal-name'` でstateを変えてrender
- カラー変数: `--green`, `--amber`, `--red`, `--purple`, `--blue` 等
- ナビゲーション: 下部固定、アイコン24px + テキスト13px

---

*最終更新: 2026年7月30日（file6 の 2026-07-29 作業ログを反映）*
