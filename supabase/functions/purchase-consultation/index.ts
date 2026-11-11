// supabase/functions/purchase-consultation/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { getAuthenticatedUser } from "../_shared/auth.ts";
import { ApiError, errorResponse, jsonResponse } from "../_shared/errors.ts";
import { callGroq } from "../_shared/groq.ts";
import { callGemini } from "../_shared/gemini.ts";
import { getUserFinancialContext } from "../_shared/financial_context.ts";

type Verdict = "affordable" | "caution" | "not_recommended" | "insufficient_data";

function buildDeterministicExplanation({
  verdict,
  strictness,
  itemName,
  priceNum,
  freeCash,
  remainingCash,
  opportunityCost,
  budgetWarning,
}: {
  verdict: Exclude<Verdict, "insufficient_data">;
  strictness: number;
  itemName: string;
  priceNum: number;
  freeCash: number;
  remainingCash: number;
  opportunityCost: string | null;
  budgetWarning: string | null;
}): string {
  const ratioPct = freeCash > 0 ? Math.round((priceNum / freeCash) * 100) : 0;
  const priceFmt = `Rp${priceNum.toLocaleString("id-ID")}`;
  const freeFmt = `Rp${freeCash.toLocaleString("id-ID")}`;
  const remFmt = `Rp${Math.abs(remainingCash).toLocaleString("id-ID")}`;
  const extraNote = [budgetWarning, opportunityCost].filter(Boolean).join(" ");

  if (verdict === "not_recommended") {
    if (strictness >= 4) {
      return `Waduh, ngaca dulu bos! Pengen beli ${itemName} seharga ${priceFmt}, padahal uang dingin lu bulan ini cuma ${freeFmt}. Kalau lu nekat checkout, dompet lu langsung tekor minus ${remFmt}! Tahan dulu nafsunya, beresin kas lu sebelum gaya-gayaan.${extraNote ? ` ${extraNote}` : ""}`;
    }
    if (strictness <= 2) {
      return `Sabar dulu ya, untuk saat ini ${itemName} (${priceFmt}) sebaiknya ditunda dulu. Uang dinginmu bulan ini tersisa ${freeFmt}, jadi kalau dipaksakan akan kurang sekitar ${remFmt} dan bisa mengganggu kebutuhan pokokmu. Yuk kumpulkan pelan-pelan dulu ya!${extraNote ? ` ${extraNote}` : ""}`;
    }
    return `Saran Coach: Sebaiknya tunda dulu beli ${itemName} (${priceFmt}). Harganya melampaui uang dingin bulananmu (${freeFmt}) sehingga berpotensi defisit ${remFmt}.${extraNote ? ` ${extraNote}` : ""}`;
  }

  if (verdict === "caution") {
    if (strictness >= 4) {
      return `Eits, rem dulu jarinya! ${itemName} (${priceFmt}) ini bakal nyedot ${ratioPct}% dari uang dingin lu (${freeFmt}), sisanya tinggal ${remFmt} doang sebulan ke depan. Kasih jeda 48 jam buat mikir—masih muat sih di hitungan, tapi jangan sampai nyesel gara-gara impulsif!${extraNote ? ` ${extraNote}` : ""}`;
    }
    if (strictness <= 2) {
      return `Boleh dipertimbangkan pelan-pelan ya! Pembelian ${itemName} (${priceFmt}) masih masuk uang dinginmu (${freeFmt}), tapi porsinya cukup besar (${ratioPct}%), menyisakan ${remFmt}. Coba tunggu 48 jam dulu biar makin yakin dan nggak impulsif.${extraNote ? ` ${extraNote}` : ""}`;
    }
    return `Perlu pertimbangan matang: ${itemName} (${priceFmt}) menyerap ${ratioPct}% uang dingin bulananmu (${freeFmt}), sehingga sisa ruang kasmu tinggal ${remFmt}. Terapkan jeda 48 jam sebelum memutuskan membeli.${extraNote ? ` ${extraNote}` : ""}`;
  }

  // affordable
  if (strictness >= 4) {
    return `Yaudah sikat aja kalau emang niat beli ${itemName} (${priceFmt})! Duit dingin lu bulan ini masih ada ${freeFmt}, jadi habis beli pun masih aman nyisa ${remFmt} (${ratioPct}% dari uang dingin). Tapi ingat, jangan cuma jago jajan—pastikan pos tabungan dan dana darurat lu juga tetap keisi biar nggak cuma wangi/keren doang tapi rekening kosong!${extraNote ? ` ${extraNote}` : ""}`;
  }
  if (strictness <= 2) {
    return `Kabar baik! Pembelian ${itemName} senilai ${priceFmt} aman untuk dibeli kok. Porsinya cuma ${ratioPct}% dari uang dinginmu (${freeFmt}), jadi kamu masih punya sisa longgar ${remFmt} buat kebutuhan lain dan tabunganmu tetap terjaga.${extraNote ? ` ${extraNote}` : ""}`;
  }
  return `Aman untuk dibeli! Harga ${itemName} (${priceFmt}) hanya mengambil ${ratioPct}% dari uang dinginmu bulan ini (${freeFmt}). Setelah membeli, sisa uang dinginmu masih aman di angka ${remFmt}.${extraNote ? ` ${extraNote}` : ""}`;
}

function contradictsVerdict(
  verdict: Exclude<Verdict, "insufficient_data">,
  text: string,
): boolean {
  const lower = text.toLowerCase();
  if (verdict === "affordable") {
    return /(hard\s*no|jangan\s+(?:lu\s+|kamu\s+)?(?:di)?beli|sebaiknya\s+ditunda|tunda\s+dulu|mending\s+(?:di)?tahan|skip\s+dulu|tidak\s+layak\s+(?:di)?beli|tidak\s+realistis\s+(?:di)?beli|uang\s+dingin\s+(?:lu\s+|kamu\s+)?(?:tidak|nggak|gak|ga)\s+cukup|sisa\s+uang\s+dingin\s+(?:lu\s+)?(?:itu\s+)?tipis)/.test(
      lower,
    );
  }
  if (verdict === "not_recommended") {
    return /(aman\s+(?:untuk|banget)\s+dibeli|gas\s+beli|sikat\s+aja|boleh\s+dibeli\s+sekarang|layak\s+dibeli\s+sekarang)/.test(
      lower,
    );
  }
  return false;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user, supabaseClient, error: authError } = await getAuthenticatedUser(req);
    if (authError || !user) {
      throw new ApiError(authError || "Unauthorized", 401, "UNAUTHORIZED");
    }

    const { item_name, estimated_price, category_name, strictness_level: clientStrictness } = await req.json();
    if (!item_name || !estimated_price) {
      throw new ApiError("Nama barang dan estimasi harga wajib diisi", 400, "MISSING_FIELDS");
    }

    const finContext = await getUserFinancialContext(supabaseClient, user.id);
    const priceNum = Number(estimated_price);
    if (isNaN(priceNum) || priceNum <= 0) {
      throw new ApiError("Estimasi harga harus berupa angka positif", 400, "INVALID_PRICE");
    }

    // 1. Check for insufficient data (PRD Phase 4 Exit Criteria: Data yang hilang menghasilkan insufficient_data)
    let verdict: Verdict = "affordable";

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

    // 2. Deterministic calculations (Golden Financial Rule)
    // Uang Dingin Siap Pakai = Total Pemasukan - Total Pengeluaran Konsumsi - Kewajiban Cicilan Belum Dibayar - Setoran Tabungan/Dana Darurat Bulan Ini
    const freeCash = finContext.availableFreeCash;
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

    const parsedClientStrictness =
      clientStrictness != null && Number(clientStrictness) >= 1 && Number(clientStrictness) <= 5
        ? Number(clientStrictness)
        : null;
    const strictness = parsedClientStrictness ?? (finContext.strictnessLevel || 3);

    const verdictLabelMap: Record<Exclude<Verdict, "insufficient_data">, string> = {
      affordable: "AMAN UNTUK DIBELI (BOLEH BELI)",
      caution: "PERLU PERTIMBANGAN (TAHAN 48 JAM / HATI-HATI)",
      not_recommended: "SEBAIKNYA DITUNDA (DILARANG / DEFISIT)",
    };

    const verdictDirective =
      verdict === "affordable"
        ? `KEPUTUSAN MUTLAK SISTEM: ${verdictLabelMap.affordable}.
- Angka hitungan membuktikan pembelian INI AMAN & MASUK BUDGET (uang dingin Rp${freeCash.toLocaleString("id-ID")}, sisa setelah beli masih positif Rp${remainingCash.toLocaleString("id-ID")}).
- Kamu WAJIB menyetujui pembelian ini ("aman dibeli" / "boleh beli" / "sikat aja"), SERTA menyebutkan angka sisa uang dingin secara akurat.
- DILARANG KERAS menolak, bilang "Hard NO", "jangan dibeli", "sebaiknya ditunda", atau mengarang seolah uang dingin tipis/kurang.`
        : verdict === "caution"
        ? `KEPUTUSAN MUTLAK SISTEM: ${verdictLabelMap.caution}.
- Harga barang mengambil >50% dari uang dingin (sisa uang dingin tinggal Rp${remainingCash.toLocaleString("id-ID")}).
- Kamu WAJIB menyarankan pertimbangkan ulang & jeda 48 jam agar tidak impulsif (bukan "aman banget" dan bukan "defisit minus").`
        : `KEPUTUSAN MUTLAK SISTEM: ${verdictLabelMap.not_recommended}.
- Harga barang melebihi uang dingin bulan ini sehingga kas bebas akan tekor minus Rp${Math.abs(remainingCash).toLocaleString("id-ID")}.
- Kamu WAJIB melarang membeli sekarang dan menyarankan tunda dulu.`;

    let personaPrompt =
      `GAYA BICARA: "TEMAN DISIPLIN & REALISTIS" (Level 3/5). Akrab, objektif, jelas berbasis angka, tetap patuh pada KEPUTUSAN MUTLAK SISTEM di atas.`;
    if (strictness >= 4) {
      personaPrompt =
        verdict === "affordable"
          ? `GAYA BICARA: "SAVAGE ROAST MODE TONGKRONGAN" (Level ${strictness}/5).
- Tetap pakai gaya ceplas-ceplos, pedas, sarkastik, dan nyebelin ala anak tongkrongan (lu/gue).
- Karena KEPUTUSAN MUTLAK = AMAN UNTUK DIBELI, sindir selera belanjanya atau ingatkan celengan dana darurat (Rp${finContext.initialEmergencyFund.toLocaleString("id-ID")}) secara menohok, LALU TETAP NYATAKAN BAHWA BARANG INI BOLEH/AMAN DIBELI karena duit dinginnya masih nyisa Rp${remainingCash.toLocaleString("id-ID")}!`
          : `GAYA BICARA: "SAVAGE ROAST MODE TONGKRONGAN" (Level ${strictness}/5).
- Sarkastik, pedas, ceplas-ceplos ala anak tongkrongan (lu/gue). Sindir tajam dan tampar realita angka uang dingin (Rp${freeCash.toLocaleString("id-ID")}) serta dampak ke dana darurat/tabungan sesuai KEPUTUSAN MUTLAK SISTEM.`;
    } else if (strictness <= 2) {
      personaPrompt = `GAYA BICARA: "TEMAN SANTAI & SUPORTIF" (Level ${strictness}/5).
- Sangat ramah, hangat, menyemangati, empatik, dan tanpa kata kasar sedikit pun, tetap 100% selaras dengan KEPUTUSAN MUTLAK SISTEM.`;
    }

    const ratioPct = freeCash > 0 ? ((priceNum / freeCash) * 100).toFixed(1) : "0.0";
    const systemPrompt =
      `Anda adalah AI Financial Coach di FinGuard untuk ${finContext.displayName}. Gunakan Bahasa Indonesia yang natural dan luwes. JANGAN gunakan tanda bintang markdown (** atau *). KEPUTUSAN FINAL kelayakan beli sudah ditentukan oleh kalkulator sistem dan TIDAK BOLEH dibantah atau dibalikkan.`;

    const prompt = `Analisis rencana belanja:
Barang: ${item_name}
Harga: Rp${priceNum.toLocaleString("id-ID")}
Kategori: ${category_name || "Umum"}
Pemasukan Bulanan: Rp${finContext.monthlyIncome.toLocaleString("id-ID")}
Kebutuhan Pokok / Pengeluaran Berjalan: Rp${finContext.essentialExpenses.toLocaleString("id-ID")}
Cicilan Utang Belum Terbayar: Rp${finContext.monthlyDebt.toLocaleString("id-ID")}
Uang Dingin Bulan Ini: Rp${freeCash.toLocaleString("id-ID")}
Porsi Harga vs Uang Dingin: ${ratioPct}%
Proyeksi Sisa Uang Dingin Setelah Beli: Rp${remainingCash.toLocaleString("id-ID")}
Dampak ke Tabungan: ${opportunityCost || "Belum ada target tabungan"}
Peringatan Jatah Belanja: ${budgetWarning || "Masih dalam batas aman"}

${verdictDirective}

${personaPrompt}

Tulis jawaban langsung (2-3 paragraf ringkas) tanpa tanda bintang markdown (** atau *), yang 100% konsisten dengan KEPUTUSAN MUTLAK SISTEM dan tetap setia pada karakter pengguna. JANGAN membuat transaksi baru apa pun.`;

    let explanation = "";
    let sourceEngine: "groq" | "gemini" | "fallback" = "fallback";

    // Primary AI: Groq -> Backup AI: Gemini -> Deterministic Fallback
    try {
      const groqText = await callGroq({
        systemInstruction: systemPrompt,
        messages: [{ role: "user", content: prompt }],
        temperature: strictness >= 4 ? 0.55 : 0.2,
        jsonMode: false,
        timeoutMs: 4000,
        maxTokens: 700,
      });
      if (groqText && !contradictsVerdict(verdict, groqText)) {
        explanation = groqText.trim();
        sourceEngine = "groq";
      }
    } catch (_) {}

    if (!explanation) {
      try {
        const geminiText = await callGemini({
          systemInstruction: systemPrompt,
          contents: [{ role: "user", parts: [{ text: prompt }] }],
          temperature: strictness >= 4 ? 0.55 : 0.2,
        });
        if (geminiText && !contradictsVerdict(verdict, geminiText)) {
          explanation = geminiText.trim();
          sourceEngine = "gemini";
        }
      } catch (_) {}
    }

    if (!explanation) {
      explanation = buildDeterministicExplanation({
        verdict,
        strictness,
        itemName: item_name,
        priceNum,
        freeCash,
        remainingCash,
        opportunityCost,
        budgetWarning,
      });
      sourceEngine = "fallback";
    }

    return jsonResponse({
      item_name,
      estimated_price: priceNum,
      verdict,
      explanation,
      source_engine: sourceEngine,
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
