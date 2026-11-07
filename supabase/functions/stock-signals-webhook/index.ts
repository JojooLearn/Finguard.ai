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

