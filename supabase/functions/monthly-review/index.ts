// supabase/functions/monthly-review/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";
import { ApiError, errorResponse, jsonResponse } from "../_shared/errors.ts";
import { callGemini } from "../_shared/gemini.ts";
import { sendPushNotification } from "../_shared/onesignal.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user, supabaseClient, error: authError } = await getAuthenticatedUser(req);
    if (authError || !user) {
      throw new ApiError(authError || "Unauthorized", 401, "UNAUTHORIZED");
    }

    const { period_start, period_end } = await req.json();
    if (!period_start || !period_end) {
      throw new ApiError("period_start dan period_end wajib diisi", 400, "MISSING_PERIOD");
    }

    // Deterministic metrics aggregation from transactions without deleted_at
    const { data: txs, error: txError } = await supabaseClient
      .from("transactions")
      .select("amount, transaction_type, note, category_id, categories(name)")
      .eq("user_id", user.id)
      .is("deleted_at", null)
      .gte("transaction_date", period_start)
      .lte("transaction_date", period_end);

    if (txError) throw txError;

    let totalIncome = 0;
    let totalExpense = 0;
    const categoryBreakdown: Record<string, number> = {};

    for (const t of txs || []) {
      const amt = Number(t.amount || 0);
      if (t.transaction_type === "income") {
        totalIncome += amt;
      } else if (t.transaction_type === "expense") {
        totalExpense += amt;
        const catName = t.categories?.name || t.note || "Belanja & Kebutuhan";
        categoryBreakdown[catName] = (categoryBreakdown[catName] || 0) + amt;
      }
    }

    const netCashFlow = totalIncome - totalExpense;

    const metricsSnapshot = {
      totalIncome,
      totalExpense,
      netCashFlow,
      transactionCount: (txs || []).length,
      categoryBreakdown,
    };

    // Fetch user strictness level
    let strictness = 3;
    try {
      const { data: fp } = await supabaseClient
        .from("financial_profiles")
        .select("strictness_level")
        .eq("user_id", user.id)
        .maybeSingle();
      if (fp && fp.strictness_level) {
        strictness = Number(fp.strictness_level);
      }
    } catch (_) {}

    let narrative = "";
    try {
      let toneRule = "Gaya bicara santai dan akrab seperti teman tongkrongan yang bijak.";
      if (strictness >= 4) {
        toneRule = "Gaya bicara ROAST MODE TONGKRONGAN: Pedas, sarkastik, ceplas-ceplos, menyindir jika defisit/boncos.";
      } else if (strictness <= 2) {
        toneRule = "Gaya bicara sangat ramah, hangat, menyemangati, dan positif.";
      }

      const prompt = `Data ringkasan bulan ini (${period_start} s/d ${period_end}):
- Total Pemasukan: Rp${totalIncome.toLocaleString("id-ID")}
- Total Pengeluaran: Rp${totalExpense.toLocaleString("id-ID")}
- Sisa Uang Bersih: Rp${netCashFlow.toLocaleString("id-ID")}
- Jumlah Transaksi: ${(txs || []).length}

Instruksi Copywriting:
${toneRule}
Bahasa: Bahasa Indonesia santai, luwes, dan bersahabat. Hindari istilah perbankan kaku seperti 'pagu anggaran', 'instrumen likuid', 'defisit kas berjalan'. Gunakan istilah 'duit dingin', 'boncos', 'jatah belanja'.
Buat 2-3 kalimat ringkas dan jujur.`;

      narrative = await callGemini({
        systemInstruction: "Anda adalah Financial Coach FinGuard yang santai dan bersahabat seperti sahabat di tongkrongan.",
        contents: [{ role: "user", parts: [{ text: prompt }] }],
      });
    } catch (_) {
      narrative = netCashFlow >= 0
        ? `Keren banget! Bulan ini kamu berhasil nyisain uang dingin Rp${netCashFlow.toLocaleString("id-ID")}. Pertahankan disiplinmu dan amankan sebagian ke celengan dana darurat ya!`
        : `Aduh, bulan ini keuanganmu boncos Rp${Math.abs(netCashFlow).toLocaleString("id-ID")}. Rem dulu nongkrong dan jajan yang ga perlu biar bulan depan dompetmu ga makin kempis!`;
    }

    // Upsert into monthly_reviews table
    try {
      await supabaseClient.from("monthly_reviews").upsert(
        {
          user_id: user.id,
          period_start,
          period_end,
          currency_code: "IDR",
          metrics_snapshot: metricsSnapshot,
          narrative,
          calculation_version: "v1",
          generated_at: new Date().toISOString(),
        },
        { onConflict: "user_id,period_start,period_end" }
      );

      // Trigger OneSignal Push Notification to user
      await sendPushNotification(
        [user.id],
        "📊 Rapor Keuangan Bulan Lalu",
        "Evaluasi keuangan bulan lalu sudah siap. Yuk, cek performa finansialmu!",
        { screen: "review", period_start, period_end }
      );
    } catch (_) {
      // Continue even if logging fails
    }

    return jsonResponse({
      period_start,
      period_end,
      metricsSnapshot,
      narrative,
      calculation_version: "v1",
    });
  } catch (err) {
    return errorResponse(err);
  }
});
