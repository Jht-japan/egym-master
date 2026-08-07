-- ============================================================
-- RLS（行レベルセキュリティ）ポリシー厳格化
-- ============================================================
-- 目的:
--   これまで全テーブル「allow all（誰でも全操作OK）」だったテスト用ポリシーを、
--   ロール（super / facility / star1-3）に応じた最小限のアクセスへ絞り込む。
--
-- 前提となる仕組み:
--   ・アプリはログイン後の Supabase セッション（JWT）で動くため、ポリシー内で
--     auth.uid() / メールアドレスが使える。
--   ・招待・アカウント削除・昇格などの管理操作は Edge Function（service role
--     キー）経由で行われ、RLS を"バイパス"するため、この厳格化の影響を受けない。
--   ・公開キー(publishable key)だけを抜き取ってもログインしていなければ
--     何も読めない/書けない状態になる（= 今回の狙い）。
--
-- 実行方法:
--   Supabase → SQL Editor に貼り付けて Run（1回だけ）。
--   ★適用後は必ず各ロールで動作確認（末尾の「動作確認」参照）。
--   もし何か動かなくなったら、末尾の「ロールバック」を実行すれば元の全許可に戻せる。
--
-- 判断①（RLS厳格化後の書き込み経路）の対応方針: ★option B で解決（2026-08-04）
--   認定・招待はクライアントから直接 trainers を書くため、ロール別に必要最小限の
--   INSERT/UPDATE/SELECT を許可する。無条件の全許可ではなく、以下に厳密にスコープする:
--     ・Star2 → 自施設の Star1 候補者のみ 招待(insert)／認定(update)／閲覧(select)
--     ・Star3 → 自施設の Star2 候補者のみ 招待(insert)／閲覧(select)（★認定はしない＝監視のみ）
--     ・いずれも「mentored_by=自分」かつ「自分の施設」の行に限定（他人の候補者は不可）
--   Edge Function 経由（option A）へ将来移す場合も、これらの許可を外すだけで両立する。
-- ============================================================


-- ─────────────────────────────────────────────
-- 0) 補助関数（security definer = 関数内では RLS を無視して安全に判定）
-- ─────────────────────────────────────────────
create or replace function public.current_email()
returns text language sql stable security definer set search_path = ''
as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.is_super()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(
  select 1 from public.user_roles
  where user_id = auth.uid() and role = 'super'
) $$;

create or replace function public.is_facility_admin(fid uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(
  select 1 from public.user_roles
  where user_id = auth.uid() and role = 'facility' and facility_id = fid
) $$;

create or replace function public.my_facility_ids()
returns setof uuid language sql stable security definer set search_path = ''
as $$ select facility_id from public.user_roles
      where user_id = auth.uid() and facility_id is not null $$;

create or replace function public.my_trainer_ids()
returns setof uuid language sql stable security definer set search_path = ''
as $$ select id from public.trainers
      where public.current_email() <> '' and lower(email) = public.current_email() $$;

-- ログイン中ユーザーが指定 role を持つか（複数ロール対応・メンター判定に使用）
create or replace function public.has_role(r text)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(
  select 1 from public.user_roles
  where user_id = auth.uid() and role = r
) $$;


-- ─────────────────────────────────────────────
-- 1) RLS を全対象テーブルで有効化
-- ─────────────────────────────────────────────
alter table public.facilities        enable row level security;
alter table public.trainers          enable row level security;
alter table public.user_roles        enable row level security;
alter table public.trainer_progress  enable row level security;
alter table public.cert_requests     enable row level security;
alter table public.test_results      enable row level security;
alter table public.invitations       enable row level security;


-- ─────────────────────────────────────────────
-- 2) 旧「allow all」ポリシーを削除
-- ─────────────────────────────────────────────
drop policy if exists allow_all_facilities        on public.facilities;
drop policy if exists allow_all_trainers           on public.trainers;
drop policy if exists allow_read_own_role          on public.user_roles;
drop policy if exists allow_all_trainer_progress   on public.trainer_progress;
drop policy if exists allow_all_cert_requests      on public.cert_requests;
drop policy if exists allow_all_test_results       on public.test_results;
drop policy if exists allow_all_invitations        on public.invitations;


-- ─────────────────────────────────────────────
-- 3) facilities（施設）
--    super: 全操作 / facility・star: 自分に紐づく施設の閲覧のみ
-- ─────────────────────────────────────────────
drop policy if exists fac_select on public.facilities;
create policy fac_select on public.facilities for select to authenticated
  using ( public.is_super() or id in (select public.my_facility_ids()) );

drop policy if exists fac_insert on public.facilities;
create policy fac_insert on public.facilities for insert to authenticated
  with check ( public.is_super() );

drop policy if exists fac_update on public.facilities;
create policy fac_update on public.facilities for update to authenticated
  using ( public.is_super() ) with check ( public.is_super() );

drop policy if exists fac_delete on public.facilities;
create policy fac_delete on public.facilities for delete to authenticated
  using ( public.is_super() );


-- ─────────────────────────────────────────────
-- 4) trainers（トレーナー）
--    super: 全操作 / facility: 自施設のトレーナー / star: 自分の行のみ
-- ─────────────────────────────────────────────
drop policy if exists tr_select on public.trainers;
create policy tr_select on public.trainers for select to authenticated
  using (
    public.is_super()
    or public.is_facility_admin(facility_id)
    or lower(email) = public.current_email()
    -- 自分が育成中の候補者（メンティー）を閲覧できる（Star2→Star1 / Star3→Star2 の育成タブ）
    or mentored_by in (select public.my_trainer_ids())
  );

drop policy if exists tr_insert on public.trainers;
create policy tr_insert on public.trainers for insert to authenticated
  with check (
    public.is_super()
    or public.is_facility_admin(facility_id)
    -- Star2 が自施設に Star1 候補者を招待（自分をメンターに設定した行のみ）
    or (
      star_level = 'star1' and public.has_role('star2')
      and mentored_by in (select public.my_trainer_ids())
      and facility_id in (select public.my_facility_ids())
    )
    -- Star3 が自施設に Star2 候補者を招待（自分をメンターに設定した行のみ）
    or (
      star_level = 'star2' and public.has_role('star3')
      and mentored_by in (select public.my_trainer_ids())
      and facility_id in (select public.my_facility_ids())
    )
  );

drop policy if exists tr_update on public.trainers;
create policy tr_update on public.trainers for update to authenticated
  using (
    public.is_super()
    or public.is_facility_admin(facility_id)
    or lower(email) = public.current_email()
    -- Star2 が自分の Star1 候補者を認定できる
    or ( star_level = 'star1' and public.has_role('star2')
         and mentored_by in (select public.my_trainer_ids()) )
    -- Star3 が自分の Star2 候補者を認定できる（担当割当がある場合のハンドシェイク）
    or ( star_level = 'star2' and public.has_role('star3')
         and mentored_by in (select public.my_trainer_ids()) )
  )
  with check (
    public.is_super()
    or public.is_facility_admin(facility_id)
    or lower(email) = public.current_email()
    or ( star_level = 'star1' and public.has_role('star2')
         and mentored_by in (select public.my_trainer_ids()) )
    or ( star_level = 'star2' and public.has_role('star3')
         and mentored_by in (select public.my_trainer_ids()) )
  );

drop policy if exists tr_delete on public.trainers;
create policy tr_delete on public.trainers for delete to authenticated
  using ( public.is_super() );


-- ─────────────────────────────────────────────
-- 5) user_roles（権限）… 閲覧のみ（書き込みは Edge Function 経由）
--    自分の role / super は全件閲覧可
-- ─────────────────────────────────────────────
drop policy if exists ur_select on public.user_roles;
create policy ur_select on public.user_roles for select to authenticated
  using ( user_id = auth.uid() or public.is_super() );
-- INSERT/UPDATE/DELETE ポリシーは作らない → クライアントからの直接書き込みは不可
-- （招待・昇格・削除は service role の Edge Function が実行）


-- ─────────────────────────────────────────────
-- 6) trainer_progress（進捗の保存データ）… 本人のみ読み書き
-- ─────────────────────────────────────────────
drop policy if exists tp_select on public.trainer_progress;
create policy tp_select on public.trainer_progress for select to authenticated
  using ( public.is_super() or trainer_id in (select public.my_trainer_ids()) );

drop policy if exists tp_insert on public.trainer_progress;
create policy tp_insert on public.trainer_progress for insert to authenticated
  with check ( trainer_id in (select public.my_trainer_ids()) );

drop policy if exists tp_update on public.trainer_progress;
create policy tp_update on public.trainer_progress for update to authenticated
  using ( trainer_id in (select public.my_trainer_ids()) )
  with check ( trainer_id in (select public.my_trainer_ids()) );


-- ─────────────────────────────────────────────
-- 7) cert_requests（認定申請）
--    本人が申請(insert) / 施設管理者・super が閲覧・承認却下(update)
-- ─────────────────────────────────────────────
drop policy if exists cr_select on public.cert_requests;
create policy cr_select on public.cert_requests for select to authenticated
  using (
    public.is_super()
    or public.is_facility_admin(facility_id)
    -- 申請者本人が自分の申請状況を確認できる
    or trainer_id in (select public.my_trainer_ids())
  );

drop policy if exists cr_insert on public.cert_requests;
create policy cr_insert on public.cert_requests for insert to authenticated
  with check ( trainer_id in (select public.my_trainer_ids()) );

drop policy if exists cr_update on public.cert_requests;
create policy cr_update on public.cert_requests for update to authenticated
  using ( public.is_super() or public.is_facility_admin(facility_id) )
  with check ( public.is_super() or public.is_facility_admin(facility_id) );


-- ─────────────────────────────────────────────
-- 8) test_results / invitations … クライアント直接利用なし → 閲覧のみ最小限
-- ─────────────────────────────────────────────
drop policy if exists tres_select on public.test_results;
create policy tres_select on public.test_results for select to authenticated
  using ( public.is_super() or trainer_id in (select public.my_trainer_ids()) );

drop policy if exists inv_select on public.invitations;
create policy inv_select on public.invitations for select to authenticated
  using ( public.is_super() );


-- ============================================================
-- 動作確認（適用後、各ロールでログインして確認すること）
--   ・super:     施設/トレーナーの一覧表示・追加・削除・昇格・育成割当
--   ・facility:  自施設トレーナー一覧・招待・認定申請の承認/却下・認定済みの昇格
--   ・star1/2/3: 自分の名前が表示される・チェック/進捗が保存され再読込で残る
--                star2: テスト採点、施設への申請通知
--   ・★star2:   「スター1育成」タブに候補者が表示される／Star1を招待できる／
--                条件達成後「スター1認定」で Star1.status='certified' が書ける
--   ・★star3:   「スター2育成」タブに候補者が表示される／Star2を招待できる／
--                担当割当のある Star2 は条件達成後「スター2認定」で status='certified' が書ける
--   ・メンター未割当（mentored_by=null）の Star1/Star2 は、施設が認定申請の承認で認定する
-- ============================================================

-- ============================================================
-- ロールバック（万一アプリが動かなくなった場合、全許可に一時的に戻す）
--   下記のコメントを外して実行 → 原因調査後、上のスクリプトを再適用。
-- ============================================================
-- create policy allow_all_facilities       on public.facilities       for all using (true) with check (true);
-- create policy allow_all_trainers          on public.trainers          for all using (true) with check (true);
-- create policy allow_all_trainer_progress  on public.trainer_progress  for all using (true) with check (true);
-- create policy allow_all_cert_requests     on public.cert_requests     for all using (true) with check (true);
-- create policy allow_all_test_results      on public.test_results      for all using (true) with check (true);
-- create policy allow_all_invitations       on public.invitations       for all using (true) with check (true);
-- create policy allow_read_own_role         on public.user_roles        for select using (auth.uid() = user_id);
