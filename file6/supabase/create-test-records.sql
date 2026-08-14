-- ============================================================
-- test_records — Star2 / Star3 確認テストの「解放申請」と「提出結果」を集約するテーブル
-- ------------------------------------------------------------
-- 用途:
--   1) テスト解放申請フロー: トレーナーが前提条件を満たした後、Super管理者へ
--      「テスト解放」を申請 → Super が承認するとテストが解放される。
--   2) テスト結果の共有: 提出したテストの点数・合否・全設問の回答とAIフィードバックを
--      非正規化して保存し、担当メンター(Star2/3)・施設・Super が閲覧できる。
--   3) 認定要件: Star2/Star3 の認定は passed=true が前提（certify-requires-test）。
--
-- ★ このスクリプトは Phase 1（バックエンド初期設定）で1回 Run する。
--   RLS はここでは有効化しない（Phase 3 の「全許可」状態に合わせる）。
--   ロール別のアクセス制限は Phase 4 の tighten-rls.sql で有効化する。
-- ============================================================

create table if not exists public.test_records (
  id uuid primary key default gen_random_uuid(),
  trainer_id uuid not null references public.trainers(id) on delete cascade,
  facility_id uuid references public.facilities(id) on delete set null,
  trainer_name text,
  trainer_email text,
  star_level text not null,                    -- 'star2' | 'star3'
  unlock_status text not null default 'none',  -- 'none' | 'requested' | 'approved' | 'rejected'
  unlock_requested_at timestamptz,
  unlock_decided_at timestamptz,
  score int,
  passed boolean not null default false,
  -- report: 非正規化した提出内容（採点者が設問定義を持たなくても表示できるようにする）
  --   { overall_comment, items:[{num, question, answer, scored, score, feedback}] }
  report jsonb,
  submitted_at timestamptz,
  updated_at timestamptz default now(),
  unique (trainer_id)
);

create index if not exists idx_test_records_facility  on public.test_records(facility_id);
create index if not exists idx_test_records_status    on public.test_records(unlock_status);
create index if not exists idx_test_records_submitted on public.test_records(submitted_at);
create index if not exists idx_test_records_level     on public.test_records(star_level);
