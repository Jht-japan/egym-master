-- ============================================================
-- trainer_progress テーブル作成（クラウド同期用）
-- ============================================================
-- Star1/2/3 アプリの進捗（チェックリスト・プログラム・お客様B/A・テスト・メモ）を
-- トレーナーごとに1行のJSONで保存する。管理画面用のサマリー（cl_pct 等）は
-- 引き続き trainers テーブルに書き戻される。
--
-- 実行方法: Supabase → SQL Editor に貼り付けて Run（1回だけ）。
-- ※ RLS は最初は「全許可（テスト用）」。本番前に tighten-rls.sql で厳格化する。
-- ============================================================

create table if not exists trainer_progress (
  id          uuid primary key default gen_random_uuid(),
  trainer_id  uuid unique references trainers(id) on delete cascade,
  checklist   jsonb default '{}'::jsonb,
  programs    jsonb default '{}'::jsonb,
  ba_data     jsonb default '[]'::jsonb,
  test        jsonb default '{}'::jsonb,
  notes       jsonb default '[]'::jsonb,
  updated_at  timestamptz default now()
);

alter table trainer_progress enable row level security;

-- 初期はテスト用の全許可ポリシー（本番前に tighten-rls.sql が置き換える）
drop policy if exists "allow_all_trainer_progress" on trainer_progress;
create policy "allow_all_trainer_progress"
  on trainer_progress for all using (true) with check (true);
