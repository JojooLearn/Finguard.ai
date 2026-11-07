// supabase/functions/purchase-consultation/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";
import { ApiError, errorResponse, jsonResponse } from "../_shared/errors.ts";
import { callGemini } from "../_shared/gemini.ts";
import { getUserFinancialContext } from "../_shared/financial_context.ts";

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user, supabaseClient, error: authError } = await getAuthenticatedUser(req);
    if (authError || !user) {
      throw new ApiError(authError || "Unauthorized", 401, "UNAUTHORIZED");
    }

    const { item_name, estimated_price, category_name } = await req.json();
    if (!item_name || !estimated_price) {
      throw new ApiError("Nama barang dan estimasi harga wajib diisi", 400, "MISSING_FIELDS");
    }

    const finContext = await getUserFinancialContext(supabaseClient, user.id);
    const priceNum = Number(estimated_price);
    if (isNaN(priceNum) || priceNum <= 0) {
      throw new ApiError("Estimasi harga harus berupa angka positif", 400, "INVALID_PRICE");
    }

    // 1. Check for insufficient data (PRD Phase 4 Exit Criteria: Data yang hilang menghasilkan insufficient_data)
    let verdict: "affordable" | "caution" | "not_recommended" | "insufficient_data" = "affordable";
    
    if (!finContext.hasVerifiedIncome || finContext.monthlyIncome <= 0) {
      verdict = "insufficient_data";
      return jsonResponse({
        item_name,
        estimated_price: priceNum,
        verdict,
        explanation: "Data profil keuangan belum lengkap (pendapatan bulanan belum terverifikasi). Silakan lengkapi profil keuangan Anda terlebih dahulu agar evaluasi kelayakan dapat dihitung secara akurat.",
        opportunity_cost: null,
        budget_warning: null,
        deterministic_metrics: {
          freeCash: 0,
          remainingCash: 0,
          priceRatioToFreeCash: null,
          availableCash: finContext.availableCash,
        },
      });
    }

    // 2. Deterministic calculations (PRD Section 15.4)
    // Kas bebas bulanan = Pendapatan - Pengeluaran Esensial - Kewajiban/Utang
    const freeCash = finContext.monthlyIncome - finContext.essentialExpenses - finContext.monthlyDebt;
    const remainingCash = freeCash - priceNum;

    // Opportunity cost calculation on goals & savings
    let opportunityCost: string | null = null;
    if (finContext.goals.length > 0) {
      const topGoal = finContext.goals[0];
      const monthlyContribution = topGoal.monthlyContribution || (topGoal.target - topGoal.current) / 6;
      if (monthlyContribution > 0) {
        const monthsDelayed = (priceNum / monthlyContribution).toFixed(1);
        opportunityCost = `Uang sebesar Rp${priceNum.toLocaleString("id-ID")} setara dengan alokasi target "${topGoal.name}" selama ~${monthsDelayed} bulan.`;
      }
    }

    // Budget warning check
    let budgetWarning: string | null = null;
    const matchedBudget = finContext.activeBudgets.find(
      (b) => b.category.toLowerCase().includes(category_name?.toLowerCase() || "") ||
             (category_name && category_name.toLowerCase().includes(b.category.toLowerCase()))
    );
    if (matchedBudget && matchedBudget.limit > 0) {
      const projectedSpent = matchedBudget.spent + priceNum;
      if (projectedSpent > matchedBudget.limit) {
        budgetWarning = `Pembelian ini akan melampaui batas belanja "${matchedBudget.category}" (Batas: Rp${matchedBudget.limit.toLocaleString("id-ID")}, Proyeksi: Rp${projectedSpent.toLocaleString("id-ID")}).`;
      }
    }

    // Deterministic Verdict Logic
    if (remainingCash < 0 || priceNum > freeCash) {
      verdict = "not_recommended";
    } else if (priceNum > freeCash * 0.5) {
      verdict = "caution";
    } else {
      verdict = "affordable";
    }

    const strictness = finContext.strictnessLevel || 3;
    let personaPrompt = "Gaya bicara: Seperti teman tongkrongan yang bijak, santai, dan realistis.";
    if (strictness >= 4) {
      personaPrompt = `GAYA BICARA: "🔥 SAVAGE ROAST MODE TONGKRONGAN" (Level ${strictness}/5).
Sarkastik, pedas, ceplas-ceplos ala anak muda tongkrongan. Sindir jika barang ini tidak realistis dibeli sekarang. Tampar realita bahwa sisa uang dingin tidak cukup dan tabungan masih minim.`;
    } else if (strictness <= 2) {
      personaPrompt = `GAYA BICARA: "TEMAN SANTAI & SUPORTIF" (Level ${strictness}/5).
Sangat ramah, hangat, menyemangati, dan jelaskan dengan bahasa sederhana tanpa menyalahkan.`;
    }

    const prompt = `Analisis rencana belanja:
Barang: ${item_name}
Harga: Rp${priceNum.toLocaleString("id-ID")}
Kategori: ${category_name || "Umum"}
Pemasukan Bulanan: Rp${finContext.monthlyIncome.toLocaleString("id-ID")}
Kebutuhan Pokok: Rp${finContext.essentialExpenses.toLocaleString("id-ID")}
Cicilan Utang: Rp${finContext.monthlyDebt.toLocaleString("id-ID")}
Uang Dingin Bulanan: Rp${freeCash.toLocaleString("id-ID")}
Proyeksi Sisa Uang Setelah Beli: Rp${remainingCash.toLocaleString("id-ID")}
Status Kelayakan: ${verdict}
Dampak ke Tabungan: ${opportunityCost || "Belum ada target tabungan"}
Peringatan Jatah Belanja: ${budgetWarning || "Masih dalam batas aman"}

Instruksi:
${personaPrompt}
Jelaskan apakah layak dibeli sekarang atau sebaiknya ditunda, berikan alasan simpel berbasis sisa uang dingin. JANGAN membuat transaksi baru apa pun.`;

    let explanation: string;
    try {
      explanation = await callGemini({
        systemInstruction: "Anda adalah AI Financial Coach di FinGuard yang santai, luwes, dan bersahabat seperti di tongkrongan. Hindari istilah teknis perbankan yang kaku.",
        contents: [{ role: "user", parts: [{ text: prompt }] }],
      });
    } catch (_) {
      // Deterministic fallback explanation if AI is offline
      if (verdict === "not_recommended") {
        explanation = strictness >= 4
            ? `Waduh, rencana beli ${item_name} senilai Rp${priceNum.toLocaleString("id-ID")} mending ditahan dulu bosque! Uang dingin lu sebulan cuma Rp${freeCash.toLocaleString("id-ID")}, kalau maksain beli dompet lu bakal langsung tekor minus Rp${Math.abs(remainingCash).toLocaleString("id-ID")}! ${opportunityCost || ""}`
            : `Saran Coach: Mending tahan dulu beli ${item_name} (Rp${priceNum.toLocaleString("id-ID")}). Harganya melebihi uang dingin bulananmu (Rp${freeCash.toLocaleString("id-ID")}), jadi bisa bikin kamu boncos Rp${Math.abs(remainingCash).toLocaleString("id-ID")}. ${opportunityCost || ""}`;
      } else if (verdict === "caution") {
        explanation = `Pikir-pikir dulu bro! ${item_name} ini bakal makan lebih dari 50% uang dingin bulananmu (sisa uang dingin tinggal Rp${remainingCash.toLocaleString("id-ID")}). Terapkan jeda 48 jam biar ga nyesel beli barang impulsif. ${opportunityCost || ""}`;
      } else {
        explanation = `Gas beli! Pembelian ${item_name} aman banget di kantong. Sisa uang dinginmu setelah beli masih ada Rp${remainingCash.toLocaleString("id-ID")}, jadi kebutuhan pokok dan tabunganmu tetap aman.`;
      }
    }

    return jsonResponse({
      item_name,
      estimated_price: priceNum,
      verdict,
      explanation,
      opportunity_cost: opportunityCost,
      budget_warning: budgetWarning,
      deterministic_metrics: {
        freeCash,
        remainingCash,
        priceRatioToFreeCash: freeCash > 0 ? (priceNum / freeCash) * 100 : null,
        availableCash: finContext.availableCash,
      },
    });
  } catch (err) {
    return errorResponse(err);
  }
});
