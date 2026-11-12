// supabase/functions/_shared/stock_price_api.ts

export interface LiveStockPrice {
  symbol: string;
  ticker: string;
  currentPrice: number;
  currency: string;
  name?: string;
  changePercent?: number;
  previousClose?: number;
}

const STOP_WORDS = new Set([
  "HARI", "INI", "DONG", "BISA", "BUAT", "YANG", "SAYA", "KAMU", "ANDA", "JUGA", "DARI", "PADA",
  "ATAU", "AKAN", "LAGI", "UDAH", "TAPI", "MAU", "NIH", "KOK", "GIMANA", "KAPAN", "SIAPA",
  "MANA", "INFO", "HALO", "PAGI", "SIANG", "SORE", "MALAM", "KALAU", "KIRA", "APA", "ADA",
  "TIDAK", "GAK", "NGGAK", "GA", "GUE", "GW", "LU", "LO", "BRO", "SIS", "MIN", "TOD",
  "NJIR", "ANJIR", "COACH", "SAHAM", "STOCK", "SINYAL", "SIGNAL", "EMITEN", "INVESTASI",
  "BELI", "JUAL", "HARGA", "ANALISA", "ANALISIS", "BURSA", "IHSG", "PROSPEK", "TURUN",
  "NAIK", "BAGUS", "CEK", "PANTAU", "CHAT", "DATA", "REKOMENDASI", "SEKARANG", "KITA",
  "KEMARIN", "BESOK", "LUSA", "MINGGU", "BULAN", "TAHUN", "KALI", "COBA", "TOLONG", "KASIH",
  "UNTUK", "DENGAN", "PEMASUKAN", "PEMASUKANNYA", "COCOK", "DANA", "UANG", "DINGIN",
  "SALDO", "GAJI", "JUTA", "RIBU", "RP", "IDR", "LOT", "LEMBAR", "TERUS", "LALU", "KALO",
  "BAGAIMANA", "TENTANG", "SAMA", "DAN", "KE", "DI", "YA", "YAH", "SIH", "KAN",
  // Additional 4-letter common Indonesian words to prevent false-positive ticker extraction
  "CUMA", "TAHU", "SAJA", "JADI", "TADI", "BILA", "CARA", "MASA", "NAMA", "RATA",
  "TIGA", "LIMA", "ENAM", "SATU", "POIN", "KATA", "BACA", "TANYA", "MINTA", "LIHAT",
  "PASTI", "BARU", "LAMA", "AWAL", "ATAS", "KIRI", "LUAR", "LAIN", "BEDA", "AGAR",
  "BIAR", "DEMI", "OLEH", "PARA", "SAAT", "TIAP", "BAGI", "BAIK", "JAUH", "KUAT",
  "ASLI", "SUKA", "LUPA", "RUGI", "CUAN", "UTANG", "PAJAK", "BAYA", "MAJU", "SINI",
  "SANA", "SITU", "KAMI", "MERE", "BANY", "SEDI", "LEBI", "KURA", "PALI", "SANG",
  "TERL", "CUKU", "HAMP", "NYAR", "SEKI", "KIRA", "MUNG", "PAST", "TENT", "JELA",
  "BENA", "SALA", "TEPA", "COCOK", "SESU", "BERA", "TANG", "HARG", "PENU", "BUKA",
  "TUTU", "TING", "REND", "VOLU", "NILAI", "BROK", "SUMM", "ORDE", "BOOK", "TOTA",
  "ANTRE", "ANTR", "JATA", "POOL", "WARA",
  // Trading strategy & 4-letter action/common words that must NOT be treated as stock tickers
  "HOLD", "SELL", "MAIN", "LOSS", "STOP", "SWING", "SCAL", "GAIN", "LONG", "HIGH",
  "LOWS", "TICK", "OPEN", "AREA", "ZONA", "JUAL", "PLAN", "WAIT", "NEXT", "FUND",
  "CASH", "DUIT", "RULE", "RISK", "SIZE", "PLUS", "NOOB", "HAKA", "HAKI", "AUTO",
  "FAST", "PLAY", "REAL", "FAKE", "PEAK", "OVER", "NONE", "ZERO", "NOTE", "VWAP",
  "MACD", "BEIS", "LIVE", "MORE", "ONLY", "JUST", "WHAT", "WHEN", "HERE", "THAT",
  "THIS", "WITH", "FROM", "HAVE", "WILL", "BEEN", "SOME", "TIME", "BACK", "LIKE",
  "WANT", "NEED", "ATUR", "IKUT", "SELA", "KALA", "MAKS", "MINI", "BAWA", "DULU",
  "PULA", "KINI", "SEGI", "SUDA", "MASI", "HARU", "BANY", "BIAR", "TUTU",
  // Additional common Indonesian words that must NEVER be mistaken for IPO/stock tickers
  "SISA", "HOLA", "WKWK", "MERE", "TBK", "PERS", "BUKA", "NIAT", "LIAT", "LIHA",
  "MAKSUD", "TAHUN", "TAHU", "CARI", "BUAT", "KAYA", "GAYA", "SAMA", "BISA"
]);

// Words that are both common Indonesian/English dictionary or company-name words AND real IDX tickers —
// ONLY match when written strictly ALL-CAPS in ticker context OR explicitly preceded by saham/emiten/ipo/kode/ticker!
const AMBIGUOUS_TICKERS = new Set([
  "ANDA", "BELI", "BUKA", "BACA", "SATU", "DUA", "TIGA", "UANG", "DANA", "KOTA",
  "BALI", "JAWA", "BUMI", "DEWA", "RAJA", "CUAN", "EMAS", "RATU", "GOLF", "WIFI",
  "FILM", "BANK", "LIFE", "HOME", "CARE", "FOOD", "GOOD", "FAST", "SAFE", "TRUE",
  "NICE", "BEST", "STAR", "MEGA", "DAYA", "MAIN", "AGRO", "MINA", "TRUS", "NUSA",
  "PURI", "SARI", "JAYA", "ROTI", "HERO", "CITY", "GOLD", "PACK", "SOLA", "BOAT",
  "INDO", "ASIA", "MATA"
]);

// Tickers that can be matched directly even without "saham" prefix ONLY if written ALL-CAPS
const UNAMBIGUOUS_POPULAR_TICKERS = new Set(["DEWA", "BUMI", "RAJA", "RATU"]);

const KNOWN_MARKET_TICKERS = new Set([
  // Top IDX Banking & Financials
  "BBCA", "BBRI", "BMRI", "BBNI", "BRIS", "ARTO", "BBTN", "BNGA", "BDMN", "NISP", "PNBN", "BJBR", "BJTM", "BBYB", "BTPS", "MEGA", "AGRO", "BBKP", "BBHI", "BMAS",
  // Top IDX Energy, Mining, Oil & Commodities
  "DEWA", "ADRO", "ANTM", "PTBA", "ITMG", "PGAS", "MDKA", "INCO", "MEDC", "BUMI", "BRMS", "ENRG", "HRUM", "INDY", "ELSA", "AKRA", "PGEO", "NCKL", "MBMA", "CUAN", "BREN", "TPIA", "BRPT", "DOID", "RAJA", "PTRO", "TOBA", "MBAP", "BSSR", "GEMS", "KKGI", "MYOH", "PSAB", "ARCI", "AMMN", "EMAS",
  // Top IDX Consumer, Telco, Tech, Property, Healthcare, Aquaculture & Infra
  "TLKM", "ASII", "GOTO", "UNVR", "ICBP", "INDF", "AMRT", "KLBF", "SIDO", "MYOR", "CPIN", "JPFA", "ACES", "MAPI", "ERAA", "EXCL", "ISAT", "JSMR", "SMGR", "INTP", "BSDE", "CTRA", "PWON", "SMRA", "HEAL", "MIKA", "SILO", "EMTK", "SCMA", "MNCN", "BUKA", "BELI", "WIFI", "CLEO", "ULTJ", "CMRY", "AVIA", "TAPG", "LSIP", "AALI", "SSMS", "DSNG", "INKP", "TKIM", "UDNG",
  // Shipping, Logistics & High-Beta IDX Tickers
  "ASSA", "SMDR", "TMAS", "NELY", "HAIS", "CBDK", "YUPI", "HGII", "INET", "KPIG", "MINA", "PACK", "SOLA", "GOLF", "BDKR", "PDPP", "TGUK", "IKPM", "DAAZ", "BOAT", "AADI", "TRUS",
  // Top US / Global Tickers
  "TSLA", "AAPL", "NVDA", "MSFT", "AMZN", "GOOG", "GOOGL", "META", "NFLX", "AMD", "INTC", "BABA", "UBER", "COIN", "PLTR"
]);

/**
 * Extracts explicit Indonesian company names (e.g. "PT Agro Bahari Nusantara Tbk")
 * so the caller can resolve the official ticker (UDNG) rather than mis-matching words inside the company name ("Agro" -> AGRO).
 */
export function extractCompanyNamesFromText(text: string): string[] {
  if (!text) return [];
  const matches = new Set<string>();
  const ptTbkRegex = /\bPT\.?\s+[A-Za-z0-9][A-Za-z0-9\s.&'-]{2,60}?\s+Tbk\b/gi;
  for (const m of text.matchAll(ptTbkRegex)) {
    const cleaned = m[0].replace(/\s+/g, " ").trim();
    if (cleaned.length >= 6) matches.add(cleaned);
  }
  if (matches.size === 0) {
    const ptNoTbkRegex = /\bPT\.?\s+(?:[A-Z][a-zA-Z0-9.&'-]+\s+){1,5}[A-Z][a-zA-Z0-9.&'-]+\b/g;
    for (const m of text.matchAll(ptNoTbkRegex)) {
      const cleaned = m[0].replace(/\s+/g, " ").trim();
      if (cleaned.length >= 8) matches.add(cleaned);
    }
  }
  return Array.from(matches).slice(0, 3);
}

/**
 * Helper to extract tickers from a single text string
 */
function extractFromSingleText(
  text: string,
  localSet: Set<string>,
  hasContext: boolean
): string[] {
  if (!text) return [];
  const result = new Set<string>();

  // Mask full company names ("PT Agro Bahari Nusantara Tbk") before tokenizing so
  // Title-Case words inside a company name ("Agro") are NEVER confused for unrelated tickers (AGRO = Bank Raya).
  const sanitizedForTokens = text
    .replace(/\bPT\.?\s+[A-Za-z0-9][A-Za-z0-9\s.&'-]{2,60}?\s+Tbk\b/gi, " ")
    .replace(/\bPT\.?\s+(?:[A-Z][a-zA-Z0-9.&'-]+\s+){1,5}[A-Z][a-zA-Z0-9.&'-]+\b/g, " ");

  // 1. Highest priority: Explicitly prefixed tickers (e.g. "ipo UDNG", "saham DEWA", "kode BELI", "e-ipo BREN")
  const explicitRegex = /\b(?:saham|sahan|emiten|ipo|e-ipo|eipo|ticker|kode)\s+([a-zA-Z]{4})\b/gi;
  for (const match of sanitizedForTokens.matchAll(explicitRegex)) {
    const candidate = match[1].toUpperCase();
    if (!STOP_WORDS.has(candidate)) {
      result.add(candidate);
    }
  }

  // Also check "analisa/analisis/cek/kalau/kalo [TICKER]" where TICKER is written in uppercase or unambiguous known ticker
  const actionRegex = /\b(?:analisa|analisis|cek|kalau|kalo|prospek|broker|harga|tentang)\s+(?:ipo\s+|saham\s+|sahan\s+|emiten\s+)?([a-zA-Z]{4})\b/gi;
  for (const match of sanitizedForTokens.matchAll(actionRegex)) {
    const rawWord = match[1];
    const candidate = rawWord.toUpperCase();
    if (STOP_WORDS.has(candidate)) continue;
    const isAllCaps = rawWord === candidate;
    if ((AMBIGUOUS_TICKERS.has(candidate) || candidate === "ANDA") && !isAllCaps) continue;
    if (isAllCaps || KNOWN_MARKET_TICKERS.has(candidate)) {
      result.add(candidate);
    }
  }

  // 2. Tokenize words cleanly (NEVER accept Title-Case/lowercase ambiguous company words like "Agro" as a ticker)
  const rawTokens = sanitizedForTokens
    .split(/[\s,/?!.;:()[\]"']+/)
    .map((w) => w.replace(/[^A-Za-z0-9.]/g, ""))
    .filter((w) => w.length >= 2);

  for (const rawToken of rawTokens) {
    const stripped = rawToken.replace(/\.JK$/i, "");
    const clean = stripped.toUpperCase();
    if (STOP_WORDS.has(clean)) continue;
    if (localSet.has(clean) || KNOWN_MARKET_TICKERS.has(clean)) {
      const isAllCapsInOriginal = stripped === clean && /^[A-Z]{4}$/.test(stripped);
      const hasPrefix = new RegExp(`(?:saham|sahan|emiten|ipo|e-ipo|eipo|kode|ticker)\\s+${clean}\\b`, "i").test(sanitizedForTokens);
      // Require ALL-CAPS or explicit ticker keyword prefix whenever token is ambiguous or mixed-case sentence word
      if (AMBIGUOUS_TICKERS.has(clean)) {
        if (!isAllCapsInOriginal && !(hasPrefix && !UNAMBIGUOUS_POPULAR_TICKERS.has(clean))) {
          if (!hasPrefix) continue;
        }
      } else if (!isAllCapsInOriginal && !hasPrefix && !hasContext) {
        continue;
      }
      result.add(clean);
    }
  }

  // 3. Generic 4-letter token fallback ONLY for explicit ALL-CAPS tickers
  if (hasContext && result.size === 0) {
    for (const rawToken of rawTokens) {
      const stripped = rawToken.replace(/\.JK$/i, "");
      const clean = stripped.toUpperCase();
      const isAllCaps = stripped === clean;
      if (
        isAllCaps &&
        clean.length === 4 &&
        /^[A-Z]{4}$/.test(clean) &&
        !STOP_WORDS.has(clean) &&
        !AMBIGUOUS_TICKERS.has(clean)
      ) {
        result.add(clean);
      }
    }
  }

  return Array.from(result);
}

/**
 * Extracts all candidate stock tickers from a user message, with multi-turn memory fallback
 * for follow-up questions (e.g., "di saham itu", "tanggal berapa dan harga penutupan berapa", "broker summary terakhir").
 */
export function extractStockTickers(
  message: string,
  knownLocalTickers: string[] = [],
  recentHistory: Array<{ sender?: string; role?: string; content?: string }> = []
): string[] {
  if (!message) return [];

  const localSet = new Set(knownLocalTickers.map((t) => t.toUpperCase()));

  const hasStockKeywordsInMsg =
    /(?:saham|sahan|stock|emiten|ticker|kode|sinyal|investasi|ihsg|bursa|chart|tradingview|dividen|trading|pasar modal|analisa|analisis|lot|pe ratio|pbv|rsi|ma50|ma20|atr|broker|bandar|bandarmologi|order\s*book|bid|offer|haka|haki|penutupan|closing|opening|ipo|e-ipo|eipo|underwriter|allotment|penjatahan|ara|arb|trailing\s*stop|stop\s*loss|cut\s*loss|take\s*profit|target\s*profit|pasang\s*buy|buy\s*limit|antre\s*beli|hold|daily|day\s*trade|swing|scalp|\bts\b|\btp\b|\bsl\b|\bcl\b)/i.test(
      message
    );
  const isShortFollowUp =
    /^(?:kalau|kalo|terus|lalu|gimana|bagaimana|coba|cek|untuk|tentang)\s+[a-zA-Z]{4}\b/i.test(
      message.trim()
    );

  // Extract from current user message first
  const currentFound = extractFromSingleText(
    message,
    localSet,
    hasStockKeywordsInMsg || isShortFollowUp
  );

  if (currentFound.length > 0) {
    return currentFound.slice(0, 4);
  }

  // Follow-up Context Memory: Recover the last discussed ticker from recentHistory when asking follow-up strategy/price/exit questions!
  const isFollowUpStockQuestion =
    hasStockKeywordsInMsg ||
    /(?:saham\s+itu|emiten\s+itu|strategi\s*(?:nya|seperti apa)?|pasang\s*(?:buy|ts|tp|sl|cl)|sampai\s*kapan|itu\s+berapa|tanggal\s+berapa|harga\s+berapa|penutupan\s+berapa|total\s+bid|total\s+offer|kode\s+broker)/i.test(
      message
    );

  // If user explicitly named a company (e.g. "PT Agro Bahari Nusantara Tbk"), do not overwrite with an unrelated old ticker from history.
  const hasExplicitCompanyName = extractCompanyNamesFromText(message).length > 0;

  if (
    !hasExplicitCompanyName &&
    isFollowUpStockQuestion &&
    Array.isArray(recentHistory) &&
    recentHistory.length > 0
  ) {
    // Traverse history from newest to oldest, enabling ALL-CAPS ticker extraction (e.g. TRUS)
    for (let i = recentHistory.length - 1; i >= 0; i--) {
      const histContent = String(recentHistory[i]?.content || "");
      if (!histContent) continue;
      const histTickers = extractFromSingleText(histContent, localSet, true);
      if (histTickers.length > 0) {
        return histTickers.slice(0, 2);
      }
    }
  }

  return [];
}

/**
 * Extracts primary candidate stock ticker from a user message.
 */
export function extractStockTicker(
  message: string,
  knownLocalTickers: string[] = [],
  recentHistory: Array<{ sender?: string; role?: string; content?: string }> = []
): string | null {
  const list = extractStockTickers(message, knownLocalTickers, recentHistory);
  return list.length > 0 ? list[0] : null;
}

async function fetchSingle(symbol: string, timeoutMs: number): Promise<LiveStockPrice | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=1d`;
    const res = await fetch(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "application/json",
      },
      signal: controller.signal,
    });
    clearTimeout(timer);

    if (!res.ok) return null;

    const data = await res.json();
    const meta = data?.chart?.result?.[0]?.meta;
    if (!meta || meta.regularMarketPrice == null) return null;

    return {
      symbol: meta.symbol || symbol,
      ticker: symbol.replace(/\.JK$/i, ""),
      currentPrice: Number(meta.regularMarketPrice),
      currency: meta.currency || "IDR",
      name: meta.longName || meta.shortName || symbol,
      changePercent: meta.regularMarketChangePercent != null ? Number(meta.regularMarketChangePercent) : undefined,
      previousClose: meta.chartPreviousClose != null ? Number(meta.chartPreviousClose) : undefined,
    };
  } catch (_err) {
    clearTimeout(timer);
    return null;
  }
}

/**
 * Fetches real-time stock price from public market data with resilient fallback and strict timeout.
 */
export async function fetchLiveStockPrice(rawTicker: string, timeoutMs = 2500): Promise<LiveStockPrice | null> {
  if (!rawTicker) return null;
  const clean = rawTicker.trim().toUpperCase();

  if (clean.endsWith(".JK")) {
    return await fetchSingle(clean, timeoutMs);
  }

  // Indonesian IDX stocks are typically 4 letters (BBCA, UNVR, TLKM, DEWA, etc.)
  if (clean.length === 4) {
    const idxResult = await fetchSingle(`${clean}.JK`, timeoutMs);
    if (idxResult) return idxResult;
    return await fetchSingle(clean, timeoutMs);
  }

  // Global / US stocks (e.g. TSLA, AAPL, F, NVDA)
  const globalResult = await fetchSingle(clean, timeoutMs);
  if (globalResult) return globalResult;
  return await fetchSingle(`${clean}.JK`, timeoutMs);
}
