# EGYM マスタートレーナー制度 — 本番稼働ガイド (Go-Live Guide)

> **目的:** これ1本で「顧客が実際に使える状態（本番稼働）」まで進められる、オーナー向けの実行手順書です。
> コーディングは不要で、作業は **Supabase の管理画面** と **GitHub へのアップロード** だけです。
> **This is the owner's execution guide** — follow the phases in order. No coding required.
>
> - 各手順の SQL / 関数ファイルは `file6/supabase/` にあります。
> - より詳しいチェック項目は `SETUP_CHECKLIST.md`、判断の経緯は `WORK_LOG_2026-08-04.md` を参照。
> - ⚠️ セキュリティ（Phase 4）は **機能テスト（Phase 3）が成功してから** 適用します。

---

## 全体像 (At a glance)

| Phase | 内容 | 場所 | 所要 | 事前購入 |
|---|---|---|---|---|
| 0 | アカウント作成・購入 | 各サービス | 30–60分 | ★ここで契約 |
| 1 | バックエンド初期設定 | Supabase | 20–30分 | — |
| 2 | 最新アプリを公開 | GitHub | 10分 | — |
| 3 | 機能テスト（セキュリティ緩い状態） | ブラウザ | 30–60分 | — |
| 4 | セキュリティ有効化 | Supabase | 5分 | — |
| 5 | 各ロールで再テスト | ブラウザ | 30分 | — |
| 6 | 本番プランへ移行 | Supabase / Vercel | 15分 | ★課金開始 |
| 7 | 本番稼働開始 | — | — | — |

---

## Phase 0 — アカウント作成・購入 (Accounts & purchases)

本番運用に必須の3点をここで用意します。**取得したキーはメモ帳などに控えておく**（後の手順で使用）。

- [ ] **Anthropic API キー（AI採点用）**
  - `https://console.anthropic.com` でサインアップ → 支払い方法を登録 → **API Keys** で新規キー作成（`sk-ant-...`）。
  - 従量課金（テスト1回あたり数円程度）。→ Phase 1 の手順3で使用。
- [ ] **Supabase 有料プラン（Pro）** ※契約は Phase 6 でOK。今はアカウントにログインできれば可。
  - 無料プランは無操作で**自動停止**するため、本番では Pro（月額 約25米ドル）が必要。
- [ ] **メール送信サービス（Resend 等）** ※設定は本格運用前に。小規模テストは Supabase 標準送信で可。
  - 招待・パスワード再設定メールを制限なく送るために使用。独自ドメインのDNS設定が必要。
- [ ] **（任意）独自ドメイン** — 専用URL・独自ドメインのメール用。年額 約1,500〜2,500円。

> 🔑 **重要:** API キーやサービスロールキーは **HTMLファイルには絶対に書かない**。
> Supabase の **Secrets** に登録します（手順3）。公開キー（publishable key）だけがHTMLに入ります。

---

## Phase 1 — バックエンド初期設定 (Supabase)

すべて Supabase 管理画面での作業です。「ファイルを開く → 中身をコピー → SQL Editor に貼り付け → **Run**」の流れ。

- [ ] **1-1. 進捗テーブル作成（クラウド保存）**
  - Supabase → **SQL Editor** → `file6/supabase/create-trainer-progress.sql` を貼り付け → **Run**。
  - 確認: **Table Editor** に `trainer_progress` が表示される。
- [ ] **1-2. 施設削除エラーの修正**
  - **SQL Editor** → `file6/supabase/fix-facility-delete-cascade.sql` を貼り付け → **Run**。
  - 確認: エラーなく `Success`。
- [ ] **1-3. AI採点 Edge Function をデプロイ**
  - Supabase → **Edge Functions** → **Create a function** → 名前を **`grade-test`** に。
  - `file6/supabase/functions/grade-test/index.ts` を貼り付け → **Deploy**（設定は既存 `bright-endpoint` と同じでOK）。
  - **Secrets** → `ANTHROPIC_API_KEY` = Phase 0 で取得した `sk-ant-...` を登録。
  - 確認: `grade-test` が「Deployed」表示。
  - ⚠️ 旧バージョン（`{prompt}` を受け取る版）をデプロイ済みなら、最新 `index.ts` で**再デプロイ**。

---

## Phase 2 — 最新アプリを公開 (GitHub → Vercel)

- [ ] `file6` 内の **HTML 7ファイル**を GitHub リポジトリ `Jht-japan/egym-master`（main）にアップロード:
  - `index.html` / `login.html` / `egym_super_account.html` / `egym_facility_app.html` /
    `egym_star1_app.html` / `egym_star2_final.html` / `egym_star3_app.html`
  - ※ `index.html` はルート（`/`）にアクセスされた際に自動で `login.html` へ転送するページ。これが無いとサイトのトップURLでログイン画面が表示されません。
- [ ] **Vercel の Root Directory を `file6` に設定**（重要）。
  - リポジトリ内では HTML 7ファイルは `file6/` 配下にあります。Vercel が既定（リポジトリ直下）を配信すると **404 になる**ため、配信元フォルダを `file6` に指定します。
  - 手順: Vercel ダッシュボード → 対象プロジェクト → **Settings** → **Build & Deployment**（または **General**）→ **Root Directory** → `file6` を入力 → **Save**。→ 次回デプロイから反映。
  - ※ これは初回のみの設定。以降は `file6` 配下の変更が自動デプロイされます。
- [ ] 確認: 数分後に `https://egym-master.vercel.app/` が更新される（Vercel が自動デプロイ）。ルートURLを開くとログイン画面が表示される。

> 💡 直近の改修（メンター引き継ぎ機能・全画面ログアウト等）を反映するため、この公開が必要です。
> ⚠️ **Root Directory = `file6` が未設定だとサイトが 404 になります。** アップロード後にトップURLが開けない場合は、まずこの設定を確認してください。

---

## Phase 3 — 機能テスト（セキュリティ緩い状態）(Functional test)

**この時点では RLS は「全許可」のまま。** まず機能が正しく動くことだけを確認します。
テスト用メールは **自分が受信できる新規アドレスを数個**用意（既存のスーパー管理者メールは招待が飛ばないので不可）。

- [ ] **3-1. super:** 施設を作成 → Star2 を追加（メール招待が届く）。施設・トレーナーの追加/削除/昇格/育成割当ができる。
- [ ] **3-2. 招待受諾:** 届いたメールの「Accept Invitation」→ **パスワード設定画面**で初回パスワードを設定 → ログインできる。
- [ ] **3-3. Star2:** 「スター1育成」タブから Star1 を招待 → その人が Star1 アプリにログインできる。
- [ ] **3-4. Star1:** チェックリスト＋ベーシックプログラムを100%に → **ページ再読み込みして残る**（＝クラウド保存OK）。
- [ ] **3-5. 認定ハンドシェイク:** Star2 側で該当 Star1 が「認定可」表示 → 「スター1認定」→ Star1 アプリに「認定されました」表示。
- [ ] **3-6. Star2 テスト:** AIテストを提出 → 点数・フィードバックが表示される（`grade-test` が動作）。
- [ ] **3-7. facility:** 自施設のトレーナー一覧表示・招待・認定申請の承認/却下ができる（承認で Star2 が認定される）。
- [ ] **3-8. Star3:** 「スター2育成」タブで Star2 を招待・監視できる（★Star2の認定ボタンは無い＝監視のみ）。
- [ ] **3-9. 施設削除:** エラーなく削除できる（手順1-2の効果）。

> 📧 招待メールは Supabase 標準送信で**送信数制限**あり。「email rate limit exceeded」が出たら約1時間待つ。迷惑メールも確認。
> ここで動かない機能があれば、次のセキュリティ適用に進む前に解決すること。

---

## Phase 4 — セキュリティ有効化 (Turn on RLS)

機能テストが全て成功したら、アクセス権をロール別に厳格化します。

- [ ] Supabase → **SQL Editor** → `file6/supabase/tighten-rls.sql` を貼り付け → **Run**（1回だけ）。
  - ※このファイルは 2026-08-04 に更新済み。Star2/Star3 の招待・認定・候補者閲覧が動くように調整済み（判断①=option B）。
- [ ] 確認: エラーなく完了する。

---

## Phase 5 — 各ロールで再テスト (Re-test under security) ★最重要

セキュリティ適用後、**Phase 3 と同じ操作をもう一度**行い、すべて動くか確認します。特に以下:

- [ ] **super:** 施設/トレーナーの一覧・追加・削除・昇格・育成割当。
- [ ] **facility:** 自施設トレーナー一覧・招待・認定申請の承認/却下（→ Star2 が認定される）。
- [ ] **Star2:** 「スター1育成」に候補者が**表示される** → Star1 を招待できる → 「スター1認定」で認定できる。
- [ ] **Star3:** 「スター2育成」に候補者が**表示される** → Star2 を招待できる →（認定ボタンは無い＝監視のみ）。
- [ ] **Star1/2/3:** 自分の進捗が保存され、再読込で残る。
- [ ] **未ログイン:** サイトの中身が何も取得できない（= セキュリティが効いている）。

> ⚠️ **もし特定の操作が動かなくなったら:** `tighten-rls.sql` の**末尾「ロールバック」**のコメントを外して Run
> すれば全許可に戻せます。その後、**どのロールのどの操作が失敗したか**を共有してください（ピンポイントで直します）。

---

## Phase 6 — 本番プランへ移行 (Upgrade to production plans)

動作が確認できたら、本番運用に耐える契約へ切り替えます。

- [ ] **Supabase を Pro プランに** アップグレード（自動停止を防ぐ・月額 約25米ドル）。
- [ ] **メール送信（Resend 等）を設定**（独自ドメインのDNS設定 → Supabase の SMTP 設定）。本格運用の招待メール制限を解消。
- [ ] **（要確認）Vercel プラン:** 商用利用の場合、無料(Hobby)プランの規約上 **Pro（月額 約20米ドル）** が必要な可能性 → 確認。
- [ ] **（任意）独自ドメインを設定**（Vercel にカスタムドメインを追加 + Supabase の Site URL / Redirect URL を更新）。

---

## Phase 7 — 本番稼働開始 (Go live)

- [ ] 実際の施設・トレーナーを super から登録し、招待を開始。
- [ ] 最初の数施設で運用を開始し、問題がないか観察（ソフトローンチ推奨）。
- [ ] 🎉 本番稼働完了。

---

## 困ったとき (Troubleshooting)

| 症状 | 対処 |
|---|---|
| セキュリティ適用後に画面が動かない | `tighten-rls.sql` 末尾のロールバックを Run → 全許可に戻す → 失敗操作を共有。 |
| 招待メールが届かない | 迷惑メール確認／`email rate limit exceeded` は約1時間待つ／既存メール宛は届かない仕様。 |
| Star2/3 の育成タブに候補者が出ない | super の「育成対象の割り当て（mentored_by）」で担当を設定（新規招待は自動設定）。 |
| AI採点が動かない | `grade-test` が Deployed か／`ANTHROPIC_API_KEY` が登録済みか／旧版なら再デプロイ。 |
| サイトが数分たっても更新されない | GitHub main への push を確認／Vercel のデプロイ状況を確認。 |
| トップURLが 404 になる | Vercel の **Root Directory** が `file6` になっているか確認（HTMLは `file6/` 配下にあるため）。 |

---

## 参照ファイル早見表 (File quick reference)

| 用途 | ファイル |
|---|---|
| 進捗テーブル作成 | `file6/supabase/create-trainer-progress.sql` |
| 施設削除の修正 | `file6/supabase/fix-facility-delete-cascade.sql` |
| AI採点関数 | `file6/supabase/functions/grade-test/index.ts` |
| セキュリティ（RLS） | `file6/supabase/tighten-rls.sql` |
| 詳細チェックリスト | `file6/SETUP_CHECKLIST.md` |
| 判断①の経緯 | `file6/WORK_LOG_2026-08-04.md` |
| 技術仕様（原本） | `claude code/EGYM_技術仕様書_ClaudeCode用.md` |

*最終更新: 2026-08-04*
