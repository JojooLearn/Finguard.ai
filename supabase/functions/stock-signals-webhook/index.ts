// supabase/functions/stock-signals-webhook/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { sendPushNotificationToAll } from "../_shared/onesignal.ts";

const ALLOWED_SIGNALS = ["BUY", "SELL", "HOLD", "STRONG_BUY", "STRONG_SELL"];

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed. Use POST." }),
      {
        status: 405,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  try {
    // 1. Validate Secret Token
    const expectedSecret =
      Deno.env.get("TV_WEBHOOK_SECRET") || "finguard_tradingview_secret_2026";

    const authHeader = req.headers.get("Authorization") || "";
    const customSecretHeader = req.headers.get("X-TV-Secret") || "";

    let token = "";
    if (authHeader.toLowerCase().startsWith("bearer ")) {
      token = authHeader.substring(7).trim();
    } else if (customSecretHeader) {
      token = customSecretHeader.trim();
    }

    if (!token || token !== expectedSecret) {
      return new Response(
        JSON.stringify({
          error: "Unauthorized: Invalid or missing webhook secret token.",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2. Parse & Validate Payload
    let body: any;
    try {
      body = await req.json();
    } catch {
      return new Response(
        JSON.stringify({ error: "Invalid JSON payload." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 2b. Live TradingView Top Gainers Fetch & Sync Action (used by Flutter Web & Mobile refresh)
    if (body?.action === "fetch_top_gainers") {
      const limit = Math.min(Math.max(Number(body?.limit) || 5, 1), 15);
      const tvController = new AbortController();
      const tvTimeout = setTimeout(() => tvController.abort(), 5000);
      try {
        const tvRes = await fetch("https://scanner.tradingview.com/indonesia/scan", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "User-Agent":
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
          },
          body: JSON.stringify({
            filter: [
              { left: "change", operation: "greater", right: 0 },
              { left: "volume", operation: "greater", right: 250000 },
            ],
            columns: [
              "name",
              "close",
              "change",
              "volume",
              "Recommend.All",
              "description",
              "RSI",
              "SMA50",
            ],
            sort: { sortBy: "change", sortOrder: "desc" },
            range: [0, limit],
          }),
          signal: tvController.signal,
        });

        if (!tvRes.ok) {
          return new Response(
            JSON.stringify({ error: `TradingView scanner HTTP ${tvRes.status}` }),
            {
              status: 502,
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            },
          );
        }

        const tvJson = await tvRes.json();
        const tvRows = Array.isArray(tvJson?.data) ? tvJson.data : [];
        const now = new Date();
        const validUntilIso = new Date(now.getTime() + 12 * 60 * 60 * 1000).toISOString();
        const nowIso = now.toISOString();

        const mappedSignals = tvRows.map((entry: any) => {
          const cols = Array.isArray(entry?.d) ? entry.d : [];
          const ticker = String(cols[0] || "").toUpperCase();
          const closePrice = Number(cols[1] || 0);
          const changePct = Number(cols[2] || 0);
          const volume = Number(cols[3] || 0);
          const recAll = cols[4] != null ? Number(cols[4]) : null;
          const companyName = String(cols[5] || ticker);

          const signalType =
            recAll != null && recAll >= 0.5
              ? "STRONG_BUY"
              : (recAll != null && recAll >= 0.05) || changePct >= 5.0
                ? "BUY"
                : "BUY";

          const volFormatted =
            volume >= 1000000
              ? `${(volume / 1000000).toFixed(1)}M`
              : `${Math.round(volume / 1000)}K`;
          const signStr = changePct >= 0 ? "+" : "";
          const analysisNotes = `Top Gainer (${signStr}${changePct.toFixed(1)}%) • Vol ${volFormatted} Lot • ${companyName}`;

          return {
            ticker,
            signal_type: signalType,
            price_at_signal: closePrice,
            timeframe: "1D",
            analysis_notes: analysisNotes,
            valid_until: validUntilIso,
            created_at: nowIso,
          };
        }).filter((s: any) => s.ticker.length > 0 && s.price_at_signal > 0);

        if (mappedSignals.length > 0) {
          const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
          const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
          if (supabaseUrl && supabaseServiceRoleKey) {
            const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);
            try {
              await supabaseAdmin.from("stock_signals").delete().neq("ticker", "");
              const { data: insertedRows } = await supabaseAdmin
                .from("stock_signals")
                .insert(mappedSignals)
                .select();
              if (insertedRows && insertedRows.length > 0) {
                return new Response(
                  JSON.stringify({ success: true, signals: insertedRows }),
                  {
                    status: 200,
                    headers: { ...corsHeaders, "Content-Type": "application/json" },
                  },
                );
              }
            } catch (_) {}
          }
        }

        return new Response(
          JSON.stringify({ success: true, signals: mappedSignals }),
          {
            status: 200,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      } catch (tvErr: any) {
        return new Response(
          JSON.stringify({ error: tvErr?.message || "Failed to fetch TradingView Top Gainers" }),
          {
            status: 502,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
          },
        );
      } finally {
        clearTimeout(tvTimeout);
      }
    }

    const rawTicker = body.ticker || body.symbol || "";
    const rawSignal = body.signal_type || body.signal || body.action || "";
    const rawPrice = body.price ?? body.price_at_signal;
    const timeframe = (body.timeframe || body.interval || "1D").toString().trim();
    const notes = body.analysis_notes || body.notes || body.message || null;
    const rawValidUntil = body.valid_until;

    // Validate Ticker
    if (typeof rawTicker !== "string" || !rawTicker.trim()) {
      return new Response(
        JSON.stringify({ error: "Field 'ticker' is required and must be a non-empty string." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }
    const ticker = rawTicker.trim().toUpperCase();

    // Validate Signal Type
    const signalType = rawSignal.toString().trim().toUpperCase().replace(/\s+/g, "_");
    if (!ALLOWED_SIGNALS.includes(signalType)) {
      return new Response(
        JSON.stringify({
          error: `Invalid 'signal_type'. Allowed values: ${ALLOWED_SIGNALS.join(", ")}`,
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Validate Price
    const price = Number(rawPrice);
    if (isNaN(price) || price < 0) {
      return new Response(
        JSON.stringify({ error: "Field 'price' or 'price_at_signal' must be a valid non-negative number." }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // Compute valid_until
    let validUntilDate: Date;
    if (rawValidUntil) {
      validUntilDate = new Date(rawValidUntil);
      if (isNaN(validUntilDate.getTime())) {
        validUntilDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
      }
    } else {
      // Default: valid for 24 hours
      validUntilDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
    }

    // 3. Insert using service_role key to bypass client RLS
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      return new Response(
        JSON.stringify({ error: "Server configuration error: missing Supabase credentials." }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

    const { data, error } = await supabaseAdmin
      .from("stock_signals")
      .insert({
        ticker,
        signal_type: signalType,
        price_at_signal: price,
        timeframe,
        analysis_notes: notes ? notes.toString().trim() : null,
        valid_until: validUntilDate.toISOString(),
      })
      .select()
      .single();

    if (error) {
      return new Response(
        JSON.stringify({ error: `Failed to insert stock signal: ${error.message}` }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // 4. Trigger Centralized OneSignal Push Notification for Stock Signal
    try {
      const formattedPrice = `Rp${price.toLocaleString("id-ID")}`;
      await sendPushNotificationToAll(
        `📈 Sinyal Saham FinGuard`,
        `Sinyal ${signalType} terdeteksi untuk ${ticker} di ${formattedPrice}. Buka untuk lihat analisa AI Coach.`,
        {
          screen: "coach",
          symbol: ticker,
          type: "stock_signal",
          signal_type: signalType,
          price: price,
        }
      );
    } catch (pushErr) {
      console.warn("[stock-signals-webhook] OneSignal push failed (non-blocking):", pushErr);
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: `Signal for ${ticker} (${signalType}) successfully recorded.`,
        data,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});

