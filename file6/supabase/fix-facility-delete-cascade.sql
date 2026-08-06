-- ============================================================
-- 施設削除エラー（FK制約）の恒久対応
-- ============================================================
-- 症状:
--   施設を削除しようとすると
--   「update or delete on table "facilities" violates foreign key
--    constraint "user_roles_facility_id_fkey" on table "user_roles"」
--   というエラーで削除できない。
--
-- 原因:
--   施設(facilities)を参照している行（user_roles / trainers / cert_requests /
--   test_results など）が残っていると、Postgres が施設の削除を拒否する。
--
-- 対応:
--   外部キーを ON DELETE CASCADE / SET NULL に貼り替え、施設を削除したら
--   紐づく行も自動的に消える（またはリンクだけ外れる）ようにする。
--   これにより、アプリ側の削除処理は現状のままで確実に成功する。
--
-- 実行方法:
--   Supabase → SQL Editor にこの内容を貼り付けて Run（1回だけでOK）。
--   ※ 制約名は Supabase 既定の "<テーブル>_<カラム>_fkey" 形式を前提。
--     もし違う名前でエラーが出た場合は、その制約名に読み替えて実行してください。
-- ============================================================

-- 1) user_roles.facility_id … 施設を消したら、その施設に紐づく役割(role)も削除
alter table user_roles drop constraint if exists user_roles_facility_id_fkey;
alter table user_roles
  add constraint user_roles_facility_id_fkey
  foreign key (facility_id) references facilities(id) on delete cascade;

-- 2) trainers.facility_id … 施設を消したら、その施設のトレーナーも削除
alter table trainers drop constraint if exists trainers_facility_id_fkey;
alter table trainers
  add constraint trainers_facility_id_fkey
  foreign key (facility_id) references facilities(id) on delete cascade;

-- 3) trainers.mentored_by … メンター(トレーナー)が消えても、育成対象は消さずに
--    担当メンターの紐付けだけを外す（NULLにする）
alter table trainers drop constraint if exists trainers_mentored_by_fkey;
alter table trainers
  add constraint trainers_mentored_by_fkey
  foreign key (mentored_by) references trainers(id) on delete set null;

-- 4) test_results.trainer_id … トレーナー削除時にテスト結果も削除
alter table test_results drop constraint if exists test_results_trainer_id_fkey;
alter table test_results
  add constraint test_results_trainer_id_fkey
  foreign key (trainer_id) references trainers(id) on delete cascade;

-- 5) cert_requests … トレーナー/施設の削除に合わせて認定申請も削除
alter table cert_requests drop constraint if exists cert_requests_trainer_id_fkey;
alter table cert_requests
  add constraint cert_requests_trainer_id_fkey
  foreign key (trainer_id) references trainers(id) on delete cascade;

alter table cert_requests drop constraint if exists cert_requests_facility_id_fkey;
alter table cert_requests
  add constraint cert_requests_facility_id_fkey
  foreign key (facility_id) references facilities(id) on delete cascade;

-- 注) trainer_progress.trainer_id は作成時に既に ON DELETE CASCADE 済み。
--     invitations.facility_id は外部キー未設定のため対象外。
