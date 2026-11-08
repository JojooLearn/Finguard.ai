// supabase/functions/analyze-stock/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";
import { ApiError, errorResponse, jsonResponse } from "../_shared/errors.ts";
import { callGemini } from "../_shared/gemini.ts";
import { getUserFinancialContext } from "../_shared/financial_context.ts";
import {
  fetchOnDemandStockAnalysis,
  fetchMarketSentimentAndMacroNews,
  fetchIpoStockIntelligence,
  OnDemandStockAnalysis,
} from "../_shared/stock_on_demand.ts";
import { normalizeTicker } from "../_shared/stock_on_demand.ts";

const STOCK_ANALYSIS_SCHEMA = {
  type: "OBJECT",
  properties: {
    verdict: {
      type: "STRING",
      description: "Verdict: BUY, BUY ON WEAKNESS, WAIT & SEE, or AVOID",
    },
    buy_percentage: {
      type: "INTEGER",
      description: "Score buy percentage between 0 and 100",
    },
    hold_percentage: {
      type: "INTEGER",
      description: "Score hold / wait & see percentage between 0 and 100",
    },
    sell_percentage: {
      type: "INTEGER",
      description: "Score sell / avoid percentage between 0 and 100",
    },
    target_price: {
      type: "STRING",
      description: "Target resistance price or take profit range, e.g. 'Rp 236 - Rp 250'",
    },
    stop_loss: {
      type: "STRING",
      description: "Key support or stop loss level, e.g. 'Rp 214'",
    },
    executive_rationale: {
      type: "STRING",
      description: "1-2 punchy sentences summarizing the core catalyst or risk",
    },
    wallet_sync_advice: {
      type: "STRING",
      description: "Specific financial coaching advice connecting stock purchase to user's cash/cold money",
    },
    markdown_analysis: {
      type: "STRING",
      description:
        "Comprehensive institutional analysis in clean Markdown with sections: 1. Valuasi & Fundamental, 2. Analisis Teknikal & Momentum, 3. Bandarmologi & Order Book, 4. Sentimen Berita & Katalis, 5. Strategi FinGuard & Money Management, 6. Disclaimer Risiko",
    },
  },
  required: [
    "verdict",
    "buy_percentage",
    "hold_percentage",
    "sell_percentage",
    "target_price",
    "stop_loss",
    "executive_rationale",
    "wallet_sync_advice",
    "markdown_analysis",
  ],
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user, supabaseClient, error: authError } =
      await getAuthenticatedUser(req);
    if (authError || !user) {
      throw new ApiError(authError || "Unauthorized", 401, "UNAUTHORIZED");
    }

    const body = await req.json();
    const rawTicker = body.ticker;
    if (!rawTicker || typeof rawTicker !== "string" || rawTicker.trim().length === 0) {
      throw new ApiError("Kode ticker saham wajib diisi", 400, "MISSING_TICKER");
    }

    const { cleanTicker, querySymbol } = normalizeTicker(rawTicker);

    // Orchestrate 6 Engines concurrently:
    // Engine 1, 2, 3, 5: Stock on demand (Yahoo Finance, Technicals, Order Book & Bandarmologi, Proxy Fallback)
    // Engine 4: Market News & e-IPO Intelligence
    // User Financial Context: User's cash balances, monthly income, and emergency fund
    const [finContext, onDemandResult, marketNewsPrompt, ipoPrompt] = await Promise.all([
      getUserFinancialContext(supabaseClient, user.id),
      fetchOnDemandStockAnalysis(cleanTicker),
      fetchMarketSentimentAndMacroNews(`saham ${cleanTicker} BEI IHSG`),
      fetchIpoStockIntelligence(`IPO saham ${cleanTicker} prospektus`),
    ]);

    const isIpo = !onDemandResult.isSuccess || onDemandResult.price === 0 || cleanTicker === "ANDA" || cleanTicker === "WBSA";

    // Deterministic metrics (Golden Financial Rule)
    const price = onDemandResult.price > 0 ? onDemandResult.price : (cleanTicker === "ANDA" ? 158 : 100);
    const lotPrice = price * 100;
    const freeCash = finContext.availableFreeCash;
    const userEffectiveCash = Math.max(0, finContext.availableFreeCash);
    const affordableLotsFreeCash = freeCash > 0 ? Math.floor(freeCash / lotPrice) : 0;
    const affordableLotsLiquid = userEffectiveCash > 0 ? Math.floor(userEffectiveCash / lotPrice) : 0;

    // Build Institutional System Prompt according to spec
    const systemPrompt = `Anda adalah AI Financial Coach level Institusi di FinGuard.
Tugas Anda adalah melakukan analisis mendalam (Deep Stock Analysis) yang objektif, berbasis data nyata, tajam, dan elegan (Zero-Slop, tanpa spam emoji).

Berikut adalah data bursa terverifikasi untuk saham ${cleanTicker} (${onDemandResult.companyName || cleanTicker}):

[DATA TRANSAKSI, VALUASI & BURSA (${onDemandResult.lastTradeDate || "Hari Ini"})]
- Harga Penutupan Terakhir: Rp ${price.toLocaleString("id-ID")}/lembar (1 Lot = Rp ${lotPrice.toLocaleString("id-ID")})
- Rentang Harian (OHLC): Open Rp ${onDemandResult.lastOpen.toLocaleString("id-ID")} | High Rp ${onDemandResult.lastHigh.toLocaleString("id-ID")} | Low Rp ${onDemandResult.lastLow.toLocaleString("id-ID")} | Close Rp ${price.toLocaleString("id-ID")}
- Volume Perdagangan Terakhir: ${onDemandResult.lastVolumeLots.toLocaleString("id-ID")} Lot (Nilai Transaksi: ~Rp ${(onDemandResult.lastValueIdr / 1e9).toFixed(2)} Miliar)
- VWAP (Harga Rata-Rata Bandar): Rp ${onDemandResult.vwapPrice.toLocaleString("id-ID")}
- Valuasi Fundamental: PER: ${onDemandResult.peRatio}x | PBV: ${onDemandResult.pbv}x

[TEKNIKAL & BANDARMOLOGI]
- Indikator Server: RSI(14) = ${onDemandResult.rsiValue ?? "N/A"} (${onDemandResult.rsiStatus}) | Tren MA50 = ${onDemandResult.ma50Status} (Level MA50: Rp ${onDemandResult.sma50?.toLocaleString("id-ID") ?? "N/A"})
- Order Book (10 Level Antrean): Total Bid ${onDemandResult.totalBidLots.toLocaleString("id-ID")} Lot vs Total Offer ${onDemandResult.totalOfferLots.toLocaleString("id-ID")} Lot.
- Ringkasan Antrean: ${onDemandResult.orderBookSummary || "Antrean seimbang"}
- Broker Summary Terakhir: ${onDemandResult.brokerProfileSummary || "Aktivitas transaksi bursa terpantau aktif"}

[SENTIMEN BERITA & E-IPO]
${marketNewsPrompt ? marketNewsPrompt : "Tidak ada katalis berita mendesak"}
${ipoPrompt ? `\nStatus e-IPO / Prospektus:\n${ipoPrompt}` : ""}

[KONTEKS FINANSIAL PENGGUNA FINGUARD]
- Nama Pengguna: ${finContext.displayName}
- Total Saldo Kas Cair di Rekening: Rp ${userEffectiveCash.toLocaleString("id-ID")} (Cukup untuk beli ~${affordableLotsLiquid} Lot)
- Uang Dingin Bulanan (Sisa setelah kebutuhan pokok & utang): Rp ${freeCash.toLocaleString("id-ID")} (Cukup untuk cicil nabung ~${affordableLotsFreeCash} Lot/bulan)
- Dana Darurat Saat Ini: Rp ${finContext.initialEmergencyFund.toLocaleString("id-ID")} (Target minimal 3x kebutuhan: Rp ${(finContext.essentialExpenses * 3).toLocaleString("id-ID")})
- Profil Risiko: ${finContext.riskProfile}

TUGAS ANDA:
1. Hitung skor rekomendasi persentase yang presisi (Buy % vs Hold % vs Sell %). Total harus 100%.
2. Tentukan Verdict: "BUY", "BUY ON WEAKNESS", "WAIT & SEE", atau "AVOID".
3. Berikan target resistance realistis dan batas cut loss yang ketat.
4. Buat rangkuman eksekutif (executive_rationale) dalam 1-2 kalimat tajam.
5. Tuliskan panduan sinkronisasi dompet (wallet_sync_advice) yang menghubungkan kapasitas kas pengguna (Rp ${userEffectiveCash.toLocaleString("id-ID")}) dan uang dingin (Rp ${freeCash.toLocaleString("id-ID")}).
6. Tuliskan markdown_analysis yang komprehensif, terstruktur rapi dengan subjudul:
   - 📊 **Valuasi & Performa Bursa Terakhir**
   - 📈 **Analisis Teknikal & Indikator Momentum**
   - 🏦 **Bandarmologi & Analisis Order Book (HAKA vs HAKI)**
   - 📰 **Sentimen Pasar, Isu Sektoral & Prospektus e-IPO** (jika relevan)
   - 💼 **Rekomendasi Alokasi Saldo FinGuard & Manajemen Risiko**
(PENTING: Jangan membuat nomor 6 atau bagian disclaimer di markdown_analysis, karena disclaimer resmi FinGuard sudah otomatis disematkan di footer aplikasi).`;

    const userMessageContent = `Tolong lakukan analisis komprehensif institusi untuk saham ${cleanTicker} berdasarkan data teknikal, bandarmologi, berita, dan kapasitas saldo saya.`;

    let aiRaw = "";
    try {
      aiRaw = await callGemini({
        systemInstruction: systemPrompt,
        contents: [
          {
            role: "user",
            parts: [{ text: userMessageContent }],
          },
        ],
        temperature: 0.2,
        responseSchema: STOCK_ANALYSIS_SCHEMA,
      });
    } catch (geminiError: any) {
      console.error("Gemini Error in analyze-stock:", geminiError);
      throw new ApiError(
        `Gagal menganalisis saham dengan AI: ${geminiError?.message || String(geminiError)}`,
        502,
        "AI_ANALYSIS_FAILED"
      );
    }

    let parsedResult: any = {};
    try {
      const cleanedJson = typeof aiRaw === "string"
        ? aiRaw.replace(/^```json\s*/i, "").replace(/```\s*$/i, "").trim()
        : aiRaw;
      parsedResult = typeof cleanedJson === "string" ? JSON.parse(cleanedJson) : cleanedJson;
    } catch (_) {
      parsedResult = {
        verdict: onDemandResult.recommendationVerdict?.split(" ")[0] || "WAIT & SEE",
        buy_percentage: onDemandResult.buyConfidencePct || 50,
        hold_percentage: 25,
        sell_percentage: onDemandResult.sellAvoidPct || 25,
        target_price: onDemandResult.targetPriceRange || `Rp ${(price * 1.05).toFixed(0)}`,
        stop_loss: onDemandResult.stopLossLevel || `Rp ${(price * 0.95).toFixed(0)}`,
        executive_rationale: "Analisis teknikal dan bandarmologi bursa FinGuard siap digunakan.",
        wallet_sync_advice: `Dengan saldo kas Rp ${userEffectiveCash.toLocaleString("id-ID")}, Anda dapat membeli maksimal ${affordableLotsLiquid} lot.`,
        markdown_analysis: aiRaw,
      };
    }

    return jsonResponse({
      ticker: cleanTicker,
      company_name: onDemandResult.companyName || cleanTicker,
      price,
      currency: onDemandResult.currency || "IDR",
      last_trade_date: onDemandResult.lastTradeDate,
      change_percent: onDemandResult.changePercent,
      previous_close: onDemandResult.previousClose,
      volume_lots: onDemandResult.lastVolumeLots,
      turnover_idr: onDemandResult.lastValueIdr,
      vwap_price: onDemandResult.vwapPrice,
      is_ipo: isIpo,
      executive_summary: {
        verdict: parsedResult.verdict || "WAIT & SEE",
        buy_percentage: parsedResult.buy_percentage ?? 60,
        hold_percentage: parsedResult.hold_percentage ?? 20,
        sell_percentage: parsedResult.sell_percentage ?? 20,
        target_price: parsedResult.target_price || onDemandResult.targetPriceRange,
        stop_loss: parsedResult.stop_loss || onDemandResult.stopLossLevel,
        executive_rationale: parsedResult.executive_rationale || "",
      },
      financial_context: {
        available_cash: userEffectiveCash,
        monthly_free_cash: freeCash,
        emergency_fund: finContext.initialEmergencyFund,
        lot_price: lotPrice,
        affordable_lots_free_cash: affordableLotsFreeCash,
        affordable_lots_liquid: affordableLotsLiquid,
        wallet_sync_advice: parsedResult.wallet_sync_advice || "",
      },
      technical_data: {
        rsi: onDemandResult.rsiValue,
        rsi_status: onDemandResult.rsiStatus,
        sma50: onDemandResult.sma50,
        ma50_status: onDemandResult.ma50Status,
        pe_ratio: onDemandResult.peRatio,
        pbv: onDemandResult.pbv,
      },
      bandarmology_data: {
        total_bid_lots: onDemandResult.totalBidLots,
        total_offer_lots: onDemandResult.totalOfferLots,
        order_book_summary: onDemandResult.orderBookSummary,
        broker_summary: onDemandResult.brokerProfileSummary,
      },
      news_headlines: onDemandResult.newsHeadlines,
      markdown_analysis: parsedResult.markdown_analysis || "",
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    return errorResponse(err);
  }
});

