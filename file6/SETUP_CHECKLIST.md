# EGYM Master Trainer System — Supabase Setup Checklist ／ Supabase セットアップ チェックリスト

**EN:** Follow these steps **in order** to turn on all the developed features (cloud sync,
AI grading, facility deletion, security). Everything is done in the Supabase dashboard and
GitHub — no coding required.

**JA:** この手順を **上から順番に** 実行すると、開発済みの機能（クラウド同期・AI採点・施設削除・
セキュリティ）がすべて有効になります。すべて Supabase の管理画面と GitHub での作業で、
コーディングは不要です。

> 📁 **EN:** All SQL / function files live in `file6/supabase/`. For each step: open the file →
> copy its contents → paste into Supabase → **Run**.
> 📁 **JA:** SQL / 関数ファイルはすべて `file6/supabase/` にあります。各手順で「ファイルを開いて
> 中身をコピー → Supabase に貼り付け → **Run**」します。

---

## Before you start ／ 事前に用意するもの

- [ ] Can log in to the Supabase project (**Jht EGYM Trainer**) ／ Supabase プロジェクト（**Jht EGYM Trainer**）にログインできること
- [ ] Have an Anthropic API key for AI grading (`console.anthropic.com`, `sk-ant-...`) ／ AI採点用の Anthropic APIキー（`console.anthropic.com` で取得、`sk-ant-...`）
- [ ] Can upload files to the GitHub repo `Jht-japan/egym-master` ／ GitHub リポジトリ `Jht-japan/egym-master` にアップロードできること

---

## Setup steps ／ セットアップ手順

### 1. Create the trainer-progress table (cloud sync) ／ トレーナー進捗テーブルを作成（クラウド同期）
- [ ] **Where ／ 場所:** Supabase → **SQL Editor**
- [ ] **Do ／ 操作:** paste `file6/supabase/create-trainer-progress.sql` and **Run** ／ `create-trainer-progress.sql` の中身を貼り付けて **Run**
- [ ] **Verify ／ 確認:** `trainer_progress` appears in the Table Editor ／ Table Editor に `trainer_progress` が表示される

---

### 2. Fix the facility-deletion error (FK CASCADE) ／ 施設削除エラーの修正（外部キー CASCADE）
- [ ] **Where ／ 場所:** Supabase → **SQL Editor**
- [ ] **Do ／ 操作:** paste `file6/supabase/fix-facility-delete-cascade.sql` and **Run** ／ `fix-facility-delete-cascade.sql` の中身を貼り付けて **Run**
- [ ] **Verify ／ 確認:** completes without errors (`Success`) ／ エラーなく完了する（`Success`）

---

### 3. Deploy the AI-grading Edge Function ／ AI採点用 Edge Function をデプロイ
- [ ] **Where ／ 場所:** Supabase → **Edge Functions** → **Create a function**
- [ ] **Do ／ 操作:** name it exactly **`grade-test`**, paste `file6/supabase/functions/grade-test/index.ts`, **Deploy** (same settings as `bright-endpoint`) ／ 関数名を **`grade-test`** にし、`index.ts` を貼り付けて **Deploy**（`bright-endpoint` と同じ設定でOK）
- [ ] **Do ／ 操作:** add the API key secret → Edge Functions → **Secrets** → `ANTHROPIC_API_KEY` = your `sk-ant-...` ／ シークレット登録 → **Secrets** → `ANTHROPIC_API_KEY` = 取得した `sk-ant-...`
- [ ] **Verify ／ 確認:** `grade-test` shows as "Deployed" ／ `grade-test` が「Deployed」と表示される

> ⚠️ **EN:** If you already deployed an older version (took `{prompt}`), **redeploy** with the latest `index.ts` — the input format changed.
> ⚠️ **JA:** 以前に旧バージョン（`{prompt}` を受け取る版）をデプロイ済みなら、最新の `index.ts` で **再デプロイ**してください（受け取る形式が変わっています）。

---

### 4. Upload the latest HTML files to GitHub ／ 最新の HTML ファイルを GitHub にアップロード
- [ ] **Where ／ 場所:** GitHub `Jht-japan/egym-master` (main branch)
- [ ] **Do ／ 操作:** upload the HTML files from `file6` (login / super / facility / star1 / star2 / star3) ／ `file6` フォルダ内の HTML ファイルをアップロード（login / super / facility / star1 / star2 / star3）
- [ ] **Verify ／ 確認:** Vercel auto-deploys and `https://egym-master.vercel.app/` updates ／ Vercel が自動デプロイし、サイトが更新される

---

### 5. Test everything (security still loose here) ／ 全体の動作テスト（この時点ではセキュリティは緩いまま）
**EN:** RLS is still "allow all" here — first confirm the features work.
**JA:** まだ RLS は「全許可」です。まず機能が正しく動くことを確認します。

- [ ] **super:** add / delete / promote trainers & facilities, assign mentees ／ 施設・トレーナーの追加／削除／昇格／育成割当ができる
- [ ] **facility manager:** sees own trainers, can invite, approve/reject cert requests ／ 自施設のトレーナー一覧・招待・認定申請の承認/却下
- [ ] **Star1/2/3:** your name shows; enter progress, **reload**, and it persists (= cloud save works) ／ 自分の名前が表示され、進捗を入力し **再読み込み** して残る（＝クラウド保存OK）
- [ ] **Star2:** submit the test → AI score + feedback appears ／ テスト提出で AI採点の点数・フィードバックが表示される
- [ ] **Facility deletion:** deletes without error (effect of step 2) ／ 施設削除がエラーなくできる（手順2の効果）
- [ ] **育成 handshake (NEW ／ 新規):** Star2 invites a Star1 from the 「スター1育成」 tab → that person can log into the Star1 app; when the Star1 finishes their checklist + basic program, the Star2 sees 100% / 「認定可」 and presses 「スター1認定」→ the Star1 app then shows 「認定されました」. Star3 → Star2 works the same way for invites/monitoring (Star2 is certified by the facility manager). ／ スター2が「スター1育成」タブから招待→本人がスター1アプリにログイン→チェックリスト＋ベーシックPG完了でスター2側に「認定可」表示→「スター1認定」でスター1本人が認定される。スター3→スター2も招待・進捗確認は同様（スター2の認定は施設管理者が実施）。
  > 💡 既存トレーナーが育成タブに出ない場合は、スーパーアカウントの「育成対象の割り当て（mentored_by）」で担当を設定してください。新規招待は自動で担当が設定されます。

> 📧 **EN:** Invite emails use Supabase's built-in sender for now, which has a **low limit**. Test by inviting **your own email addresses** a few at a time; if you see "email rate limit exceeded", wait ~1 hour. Check spam too.
> 📧 **JA:** 招待メールは現在 Supabase 標準送信のため **送信数制限**があります。**自分が確認できるメール宛**に少数ずつテストし、「email rate limit exceeded」が出たら1時間ほど待つ。迷惑メールも確認。

---

### 6. Tighten security (RLS) ／ セキュリティ（RLS）を厳格化 ★ important / 重要
**EN:** Once features work, restrict access per role.
**JA:** 機能が動くことを確認したら、アクセス権をロール別に絞ります。

- [ ] **Where ／ 場所:** Supabase → **SQL Editor**
- [ ] **Do ／ 操作:** paste `file6/supabase/tighten-rls.sql` and **Run** ／ `tighten-rls.sql` の中身を貼り付けて **Run**
- [ ] **Re-test ／ 再テスト:** repeat the step-5 tests for each role and confirm all still work ／ 手順5の各ロールを再テストし、すべて動くか確認
- [ ] **Verify ／ 確認:** when not logged in, nothing can be read ／ 未ログインでは何も取得できない

> ⚠️ **EN:** If a screen breaks after RLS, uncomment the "Rollback" block at the bottom of `tighten-rls.sql` and Run it to revert to allow-all, then tell me which operation failed.
> ⚠️ **JA:** RLS 適用後に画面が動かなくなったら、`tighten-rls.sql` 末尾の「ロールバック」のコメントを外して Run すれば全許可に戻せます。その後、失敗した操作を共有してください。

---

## Before going to production (skip for now) ／ 本番移行前に対応（今はスキップOK）

- [ ] **Custom-domain email (Resend SMTP)** — so invite / password-reset emails send without limits; needs DNS access, handle before go-live. ／ **独自ドメインでのメール送信（Resend SMTP）** — 招待・パスワード再設定メールを制限なく送るための設定。DNS設定が必要なため本番前に対応（手順は別途）。

---

## File quick reference ／ 参照ファイル早見表

| Step ／ 手順 | File ／ ファイル |
|---|---|
| 1 | `file6/supabase/create-trainer-progress.sql` |
| 2 | `file6/supabase/fix-facility-delete-cascade.sql` |
| 3 | `file6/supabase/functions/grade-test/index.ts` |
| 6 | `file6/supabase/tighten-rls.sql` |

*Last updated ／ 最終更新: 2026-07-22*
