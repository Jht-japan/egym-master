// EGYM Star2 / Star3 確認テスト AI採点 Edge Function
// -------------------------------------------------------------
// 模範解答（ANSWER_KEY）はこのサーバー側関数に保持し、クライアント（HTML）には出さない。
// クライアントは受験者の回答と設問だけを送信する:
//   POST https://<project>.functions.supabase.co/functions/v1/grade-test
//   body: { questions: [{ num, id, question, answer }] }
//   → 返り値: { scores:[{id,score,feedback}], total_score, overall_comment }
//
// デプロイ手順（どちらか）:
//   A) Supabase CLI:  supabase functions deploy grade-test --no-verify-jwt
//   B) ダッシュボード: Edge Functions → Create a function → 名前 "grade-test"
//      → このファイルの内容を貼り付け → Deploy（bright-endpoint と同じ設定でOK）
//
//   デプロイ後、Anthropic APIキーをシークレットに登録:
//     supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxxx
//   （ダッシュボードの Edge Functions → Secrets からでも登録可）

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY");

// 模範解答のポイント（採点基準）— 端末には出さない
const ANSWER_KEY: Record<string, string> = {
  q1: "ベーシックプログラムは1つの基本プログラムで構成され、RegularとNegativeの負荷方法を使用して筋力向上を行う。比較的低負荷でトレーニング初心者でも取り組みやすく、運動を習慣化することを目的とする。EGYM+は8つの目的別プログラムがあり、5つの負荷方法を使用。筋力向上、減量、健康改善など会員の目的に応じたトレーニングが可能。使い分けは初心者にはベーシック、目的が明確な場合はEGYM+を選択する。",
  q2: "BioAgeとはEGYMの各種測定データを基に算出される身体年齢の指標。筋力（EGYMストレングスマシン）、柔軟性（Fitness Hub）、代謝（体組成計）、持久力（VO2maxまたは心拍数・Matrixカーディオ）のデータを総合的に評価して算出される。会員の体力レベルを可視化しモチベーション向上につなげることを目的とする。",
  q3: "同じトレーニングを続けると身体がその刺激に慣れてしまうため、フェーズごとに負荷方法やトレーニング内容を変えることで常に新しい刺激を与え、効率的に筋力向上・体力向上を図るため。初期はフォーム習得、中盤は筋力向上、後半は最大刺激やパワー向上といった段階的なアプローチができる。",
  q4: "プログラムの名前を2つ挙げ、各Phase（フェーズ1〜4）の目的と負荷方法（Regular/Negative/Adaptive/Isokinetic/Explonicなど）が具体的に説明されていれば正解。フェーズごとの目的の変化や負荷方法の理由が述べられているとより高評価。",
  q5: "店舗の会員ニーズや特徴を考慮してプログラムを2つ選び、各Phaseの目的と負荷方法を説明できていれば正解。選んだ理由が店舗の状況と合致していると高評価。",
  q6: "免疫向上：体調改善・免疫機能向上を目的とし中〜低負荷で継続しやすいトレーニング。リハビリ：関節や筋肉への負担を最小限にした低負荷、可動域改善・機能回復が目的。メタボリックフィット：脂肪燃焼と代謝向上を目的とし中負荷・高回数で心拍数を維持。一般的な筋肉増加：筋肥大を目的とした高負荷・低回数で強い刺激を与えるトレーニング。",
  q7: "タスク機能は会員のトレーニング状況や進捗を把握し適切なタイミングでサポートするために重要。フォームの乱れ・モチベーション低下・進捗停滞などに対して見逃さず対応できる。フォームチェックやBioAge確認をタスクとして設定することで具体的な改善提案や声掛けが可能となり会員の継続率・満足度の向上につながる。",
  q8: "具体的な2つのタスク内容と、それが会員サポートや継続率向上にどうつながるかの理由が述べられていれば正解。例：BioAge確認タスク、筋力テスト後のフォロー、来館頻度低下時のアラートなど。",
  q9: "会員一人ひとりの目標や体力レベルに合わせた個別対応、BioAgeや筋力データを活用した進捗の可視化、定期的な声掛けやフォローアップ、トレーニングの習慣化支援などが含まれていれば正解。",
  q10: "運動経験がないため高負荷を避け安全に運動習慣を作りながら減量と基礎体力向上を進める。ベーシックプログラムまたは基礎体力向上に適したEGYM+プログラムから開始し慣れたらメタボリックフィットなどを組み合わせる。安全性・継続性・減量効果を重視した理由が述べられていれば正解。",
  q11: "体組成計データ（体重・体脂肪率・筋肉量・BMA）、筋力データ（EGYMストレングスマシン）、トレーニング回数・内容が含まれていれば正解。BioAgeも含まれるとより高評価。",
  q12: "①大筋群の筋肉量を増やして基礎代謝を向上させること、②有酸素運動や活動量増加で消費カロリーを増やすこと、③カロリー摂取コントロールとタンパク質摂取・栄養バランス。3つのポイントが具体的に説明されていれば正解。",
  q13: "原因確認（来館頻度・フォーム・負荷設定・食事・モチベーション低下のヒアリング）→プログラム内容見直し・負荷設定調整・フォーム指導・目標再確認・声掛け強化という流れで対応。",

  // ── Star3（マスタートレーナー）確認テスト。ビジネス・リーダーシップ領域。設問・基準は要確認（JHTJapan）。──
  s3q1: "リーダーシップの3要素。例：①明確なビジョン・目標の提示と共有、②率先垂範・信頼構築・コミュニケーション、③メンバーの強みを活かす育成／権限委譲とデータに基づく公正な評価。3点が具体的で、それぞれ理由が述べられていれば正解。店舗成果とチームの一体感に結びつける視点があると高評価。",
  s3q2: "モチベーションと品質向上。データに基づく客観的評価、定期的な1on1・フィードバック、成功事例の共有とロールプレイ、目標設定と達成の承認、キャリアパスの提示など、育成的な関わりが述べられていれば正解。品質標準化の仕組みに触れると高評価。",
  s3q3: "LTV（生涯価値）向上。成果の可視化（BioAge・筋力の改善）で継続を促す、目的に合った継続的プログラム提案、パーソナル等の上位サービス提案、満足度向上による長期在籍と紹介。会員価値を長期で高める視点が述べられていれば正解。",
  s3q4: "データによる信頼構築。来館履歴で変化に気づき声掛け、BioAge・筋力の改善を可視化して成果を共有、タスクで個別フォロー、面談で目標を再確認。データを『会員のため』に使い関係を深める姿勢があれば正解。",
  s3q5: "退会原因の分析。データ面（来館頻度の低下、成果指標の停滞、タスク未対応）と行動・心理面（モチベーション低下、目標未達、人間関係、料金）を切り分けて分析し、予兆サイン（来館間隔の延び・予約キャンセル増等）を挙げていれば正解。",
  s3q6: "退会防止・改善の仕組み。予兆段階での早期の声掛け・面談、目標再設定と成果の可視化、プログラム見直し、来館促進（タスク・イベント）、チームでの情報共有と対応の標準化・KPI管理。個人対応と店舗の仕組みの両面があれば正解。",
  s3q7: "新規獲得の体験設計。BioAge測定など『見える化』を活かした無料体験・測定会、データに基づく具体的提案、EGYMの差別化ポイントの訴求、SNS・地域連携。EGYMの強みを獲得に結びつける具体策があれば正解。",
  s3q8: "成約率・紹介の向上。体験時の丁寧なヒアリングと目標に沿った提案、成果イメージの提示、入会後の不安解消で成約率を高める。紹介はキャンペーン・満足度向上・紹介しやすい仕組み。成約と紹介の両面に触れていれば正解。",
  s3q9: "感じている問題点（店舗ごとに異なるため唯一の正解はない）。現場の課題を具体的に挙げ、なぜ問題か（会員・チーム・経営への影響）を論理的に説明できていれば高評価。抽象的・根拠が乏しい・影響が語られていない場合は低評価。",
  s3q10: "改善提案（唯一の正解はない）。s3q9の問題点に対応した、具体的で実行可能な改善策であること。誰が・何を・どう行い、どんな効果を期待するかまで述べられ、問題と改善が論理的につながっていれば高評価。実行可能性が乏しい／問題と対応しない場合は低評価。",
  s3q11: "ケース分析。確認すべきデータ：退会率・退会理由、新規入会数・成約率、来館頻度、成果指標（BioAge等）の推移、トレーナーの稼働・満足度。課題を退会・新規・チームの観点に分けて優先順位づけできていれば正解。",
  s3q12: "ケース改善策。退会改善（予兆フォロー・成果可視化・面談）と新規獲得（体験設計・成約率・紹介）の両面から具体策を挙げ、実行の優先順位と理由、チームへの動機づけ・役割分担まで述べられていれば正解。実行計画に踏み込めていれば高評価。",
};

interface QuestionInput {
  num?: number;
  id?: string;
  question?: string;
  answer?: string;
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function buildPrompt(questions: QuestionInput[]): string {
  let prompt =
    "あなたはEGYMマスタートレーナー認定試験の採点者です。\n以下の" +
    questions.length +
    "問について、受験者がEGYMのトレーニングシステムを正しく理解しているかを評価してください。\n\n" +
    "【採点基準】\n" +
    "- 模範解答と一字一句同じである必要はありません\n" +
    "- 概念や本質を理解していれば正解とします\n" +
    "- 各問は0〜10点で採点してください\n" +
    "- 未回答や非常に短い回答は0点にしてください\n" +
    "- フィードバックは日本語で1〜2文で具体的に書いてください\n\n";

  questions.forEach((q, i) => {
    const num = q.num ?? i + 1;
    const model = (q.id && ANSWER_KEY[q.id]) || "";
    prompt +=
      "---\n問" + num + "：" + (q.question || "") +
      "\n模範解答のポイント：" + model +
      "\n受験者の回答：" + (q.answer || "（未回答）") + "\n\n";
  });

  prompt +=
    '---\n以下のJSON形式のみで回答してください（他のテキストは不要）：\n' +
    '{"scores":[{"id":"q1","score":8,"feedback":"フィードバック"},...],"total_score":75,"overall_comment":"全体的なコメント（2〜3文）"}';

  return prompt;
}

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "POST のみ対応しています" }, 405);
  }

  try {
    if (!ANTHROPIC_API_KEY) {
      return json({ error: "ANTHROPIC_API_KEY が設定されていません" }, 500);
    }

    const body = await req.json().catch(() => null);
    const questions: QuestionInput[] = body?.questions;
    if (!Array.isArray(questions) || questions.length === 0) {
      return json({ error: "questions がありません" }, 400);
    }

    const prompt = buildPrompt(questions);

    const res = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-5",
        max_tokens: 2000,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    const data = await res.json();
    if (!res.ok) {
      return json({ error: data?.error?.message || "AI採点に失敗しました" }, 502);
    }

    // Anthropic のレスポンスから JSON ブロックを抽出
    const raw = (data.content || [])
      .map((c: { text?: string }) => c.text || "")
      .join("");
    const match = raw.match(/\{[\s\S]*\}/);
    if (!match) {
      return json({ error: "採点結果の解析に失敗しました" }, 502);
    }

    const result = JSON.parse(match[0]);
    return json(result, 200);
  } catch (err) {
    return json({ error: String((err as Error)?.message || err) }, 500);
  }
});
