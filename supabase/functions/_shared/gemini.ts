// supabase/functions/_shared/gemini.ts
import { ApiError } from "./errors.ts";

export interface GeminiContentPart {
  text?: string;
  inlineData?: {
    mimeType: string;
    data: string;
  };
  inline_data?: {
    mime_type: string;
    data: string;
  };
}

export interface GeminiMessage {
  role: "user" | "model";
  parts: GeminiContentPart[];
}

export async function callGemini({
  systemInstruction,
  contents,
  temperature = 0.2,
  responseSchema,
  responseModalities,
  speechConfig,
  timeoutMs = 18000,
  maxOutputTokens,
  preferReasoning = true,
}: {
  systemInstruction?: string;
  contents: GeminiMessage[];
  temperature?: number;
  responseSchema?: Record<string, unknown>;
  responseModalities?: string[];
  speechConfig?: Record<string, unknown>;
  timeoutMs?: number;
  maxOutputTokens?: number;
  preferReasoning?: boolean;
}) {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new ApiError("GEMINI_API_KEY environment variable is not configured", 500, "MISSING_AI_KEY");
  }

  const envModel = Deno.env.get("GEMINI_MODEL")?.trim();
  const baseCandidates = preferReasoning
    ? ["gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite"]
    : ["gemini-2.0-flash", "gemini-2.5-flash", "gemini-2.0-flash-lite"];
  const modelCandidates = Array.from(
    new Set([
      ...(envModel ? [envModel] : []),
      ...baseCandidates,
    ])
  );

  // Normalize inlineData -> inline_data for Gemini REST v1beta multimodal compatibility
  const normalizedContents = contents.map((msg) => ({
    role: msg.role,
    parts: msg.parts.map((p) => {
      if (p.inlineData) {
        return {
          inline_data: {
            mime_type: p.inlineData.mimeType,
            data: p.inlineData.data,
          },
        };
      }
      return p;
    }),
  }));

  // Sanitize contents for Google Gemini API Multi-Turn Rules:
  // 1. Gemini strictly requires the first turn to be role "user".
  // 2. Turns must strictly alternate between "user" and "model".
  let sanitizedContents: Array<{ role: string; parts: any[] }> = [];
  let startIndex = 0;
  while (startIndex < normalizedContents.length && normalizedContents[startIndex].role === "model") {
    startIndex++;
  }
  const nonLeadingModelContents = normalizedContents.slice(startIndex);

  for (const item of nonLeadingModelContents) {
    if (!item.parts || item.parts.length === 0) continue;
    if (sanitizedContents.length > 0 && sanitizedContents[sanitizedContents.length - 1].role === item.role) {
      sanitizedContents[sanitizedContents.length - 1].parts.push(...item.parts);
    } else {
      sanitizedContents.push({
        role: item.role,
        parts: [...item.parts],
      });
    }
  }

  if (sanitizedContents.length === 0) {
    sanitizedContents = [{ role: "user", parts: [{ text: "Halo Coach FinGuard!" }] }];
  }

  const buildRequestBody = (includeSchema: boolean) => {
    const body: any = {
      contents: sanitizedContents,
      generationConfig: {
        temperature,
        ...(typeof maxOutputTokens === "number" ? { maxOutputTokens } : {}),
      },
      safetySettings: [
        { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
      ],
    };

    if (systemInstruction) {
      body.systemInstruction = {
        parts: [{ text: systemInstruction }],
      };
    }

    if (responseSchema) {
      body.generationConfig.responseMimeType = "application/json";
      if (includeSchema) {
        body.generationConfig.responseSchema = responseSchema;
      }
    } else if (responseModalities && responseModalities.length > 0) {
      body.generationConfig.responseModalities = responseModalities;
      if (speechConfig) {
        body.generationConfig.speechConfig = speechConfig;
      }
    }
    return body;
  };

  const deadline = Date.now() + timeoutMs;
  let lastError = "";
  for (const model of modelCandidates) {
    const remainingMs = deadline - Date.now();
    if (remainingMs < 1500) break;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), remainingMs);
    try {
      let res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(buildRequestBody(true)),
        signal: controller.signal,
      });

      // If multimodal + responseSchema triggered 400 on a specific model, retry with JSON mimeType only
      if (!res.ok && res.status === 400 && responseSchema) {
        res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(buildRequestBody(false)),
          signal: controller.signal,
        });
      }

      if (!res.ok) {
        lastError = `${model} (${res.status}) - ${(await res.text()).slice(0, 200)}`;
        continue;
      }

      const json = await res.json();
      const candidate = json.candidates?.[0];
      const responseText = candidate?.content?.parts?.[0]?.text;
      if (responseText) return responseText;
      lastError = `${model} empty (finish=${candidate?.finishReason || json?.promptFeedback?.blockReason || "unknown"})`;
    } catch (err: any) {
      lastError = err?.name === "AbortError"
        ? `${model} timeout (${timeoutMs}ms)`
        : (err?.message || String(err));
    } finally {
      clearTimeout(timer);
    }
  }

  throw new ApiError(`All Gemini models failed: ${lastError}`, 502, "AI_GATEWAY_ERROR");
}

export interface GeminiGoogleSearchResult {
  text: string;
  sources: Array<{ title: string; uri: string }>;
}

/**
 * Runs a live Google Search-grounded Gemini query (`tools: [{ google_search: {} }]`)
 * to research real-time IDX/BEI tickers, company names (e.g. "PT Agro Bahari Nusantara Tbk" -> UDNG),
 * current e-IPO pipeline status, and verified market news without hallucinating non-existent tickers.
 */
export async function callGeminiWithGoogleSearch({
  prompt,
  systemInstruction,
  temperature = 0.1,
  timeoutMs = 12000,
  maxOutputTokens = 1024,
}: {
  prompt: string;
  systemInstruction?: string;
  temperature?: number;
  timeoutMs?: number;
  maxOutputTokens?: number;
}): Promise<GeminiGoogleSearchResult> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey || !prompt.trim()) {
    return { text: "", sources: [] };
  }

  const models = ["gemini-2.5-flash", "gemini-2.0-flash"];
  const deadline = Date.now() + timeoutMs;

  for (const model of models) {
    const remainingMs = deadline - Date.now();
    if (remainingMs < 1500) break;

    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), remainingMs);

    try {
      const body: Record<string, unknown> = {
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
        generationConfig: {
          temperature,
          maxOutputTokens,
        },
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
        ],
      };

      if (systemInstruction && systemInstruction.trim().length > 0) {
        body.systemInstruction = { parts: [{ text: systemInstruction }] };
      }

      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      if (!res.ok) {
        const errSnippet = (await res.text()).slice(0, 160);
        console.warn(`[gemini-search] ${model} HTTP ${res.status}: ${errSnippet}`);
        continue;
      }

      const json = await res.json();
      const candidate = json.candidates?.[0];
      const parts = Array.isArray(candidate?.content?.parts) ? candidate.content.parts : [];
      const text = parts
        .map((p: any) => (typeof p?.text === "string" ? p.text : ""))
        .join("\n")
        .trim();

      const chunks = candidate?.groundingMetadata?.groundingChunks || [];
      const sources: Array<{ title: string; uri: string }> = [];
      for (const ch of chunks) {
        const web = ch?.web;
        if (web?.uri) {
          sources.push({
            title: String(web.title || web.uri).trim(),
            uri: String(web.uri).trim(),
          });
        }
      }

      if (text.length > 0) {
        return { text, sources: sources.slice(0, 5) };
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.warn(`[gemini-search] ${model} error: ${msg}`);
    } finally {
      clearTimeout(timer);
    }
  }

  return { text: "", sources: [] };
}

/**
 * Wraps raw 16-bit mono PCM audio (e.g. 24000 Hz from Gemini TTS / AUDIO modality)
 * into a standard 44-byte RIFF WAV container encoded as Base64 so just_audio can stream it in-memory.
 */
export function wrapPcm16ToWavBase64(pcmBase64: string, sampleRate = 24000): string {
  const binaryStr = atob(pcmBase64.replace(/^data:audio\/[^;]+;base64,/, "").trim());
  const pcmLen = binaryStr.length;
  // Check if it already starts with "RIFF"
  if (pcmLen >= 4 && binaryStr.substring(0, 4) === "RIFF") {
    return btoa(binaryStr);
  }

  const wavBuffer = new ArrayBuffer(44 + pcmLen);
  const view = new DataView(wavBuffer);
  const bytes = new Uint8Array(wavBuffer);

  const writeStr = (offset: number, str: string) => {
    for (let i = 0; i < str.length; i++) {
      view.setUint8(offset + i, str.charCodeAt(i));
    }
  };

  const numChannels = 1;
  const bitsPerSample = 16;
  const byteRate = (sampleRate * numChannels * bitsPerSample) / 8;
  const blockAlign = (numChannels * bitsPerSample) / 8;

  writeStr(0, "RIFF");
  view.setUint32(4, 36 + pcmLen, true);
  writeStr(8, "WAVE");
  writeStr(12, "fmt ");
  view.setUint32(16, 16, true); // Subchunk1Size (16 for PCM)
  view.setUint16(20, 1, true); // AudioFormat (1 = PCM)
  view.setUint16(22, numChannels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);
  writeStr(36, "data");
  view.setUint32(40, pcmLen, true);

  for (let i = 0; i < pcmLen; i++) {
    bytes[44 + i] = binaryStr.charCodeAt(i);
  }

  let outBin = "";
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    outBin += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(outBin);
}

export interface CoachVoiceProfile {
  voiceName: string;
  characterLabel: string;
  styleInstruction: string;
}

/**
 * Maps FinGuard's active Coach persona (`strictnessLevel` 1..5) to a distinct
 * Gemini HD voice preset and natural Indonesian speaking direction.
 */
export function resolveCoachVoiceProfile(strictnessLevel = 3): CoachVoiceProfile {
  if (strictnessLevel <= 2) {
    return {
      voiceName: "Aoede",
      characterLabel: "Suportif",
      styleInstruction:
        "Bacakan kalimat berikut dengan suara wanita Indonesia yang hangat, lembut, ramah, dan suportif menyemangati seperti sahabat dekat",
    };
  }
  if (strictnessLevel === 3) {
    return {
      voiceName: "Charon",
      characterLabel: "Pro",
      styleInstruction:
        "Bacakan kalimat berikut dengan intonasi profesional yang tenang, jernih, tegas, dan berwibawa dalam Bahasa Indonesia yang natural",
    };
  }
  return {
    voiceName: "Fenrir",
    characterLabel: "Roast",
    styleInstruction:
      "Bacakan kalimat berikut dengan gaya bicara santai namun tegas, tajam, ekspresif, agak sarkas, dan berenergi seperti teman tongkrongan Indonesia yang lagi meroasting",
  };
}

function sanitizeTextForSpeechSynthesis(rawText: string): string {
  const clean = rawText
    .replace(/https?:\/\/\S+/g, "")
    .replace(/[━─═_]{3,}/g, ", ")
    .replace(/[*#`~>|]/g, "")
    .replace(/(^|\n)\s*[•\-]\s+/g, "$1")
    .replace(/Rp\.?\s*(\d[\d.]*)/gi, "$1 rupiah")
    .replace(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]/gu, "")
    .replace(/\n+/g, ". ")
    .replace(/\s{2,}/g, " ")
    .trim();

  if (clean.length <= 260) return clean;
  const sliced = clean.slice(0, 260);
  const lastBreak = Math.max(
    sliced.lastIndexOf("."),
    sliced.lastIndexOf("?"),
    sliced.lastIndexOf("!"),
    sliced.lastIndexOf(",")
  );
  return (lastBreak > 100 ? sliced.slice(0, lastBreak + 1) : sliced).trim();
}

function parseSampleRateFromMime(mimeType: string, fallback = 24000): number {
  const match = mimeType.match(/rate=(\d+)/i);
  if (match && match[1]) {
    const parsed = Number(match[1]);
    if (Number.isFinite(parsed) && parsed >= 8000 && parsed <= 48000) {
      return parsed;
    }
  }
  return fallback;
}

/**
 * Generates contextual AI Voice-Out via Gemini Native TTS
 * when `request_audio === true`, matching the active Coach character's voice and style.
 * Uses ultra-fast gemini-3.8-flash-lite-tts as primary model with generous 18s timeout.
 */
export async function generateGeminiSpeechAudio(
  textToSpeak: string,
  strictnessOrVoice: number | string = 3,
  timeoutMs = 18000
): Promise<string | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey || !textToSpeak || textToSpeak.trim().length === 0) return null;

  const cleanText = sanitizeTextForSpeechSynthesis(textToSpeak);
  if (!cleanText) return null;

  const profile: CoachVoiceProfile =
    typeof strictnessOrVoice === "number"
      ? resolveCoachVoiceProfile(strictnessOrVoice)
      : {
          voiceName: strictnessOrVoice,
          characterLabel: "Custom",
          styleInstruction:
            "Bacakan balasan Coach keuangan ini dengan nada santai dan natural dalam Bahasa Indonesia",
        };

  const envTtsModel = Deno.env.get("GEMINI_TTS_MODEL");
  const audioModels = Array.from(
    new Set([
      ...(envTtsModel ? [envTtsModel] : []),
      "gemini-3.8-flash-lite-tts",
      "gemini-3.8-flash-tts",
      "gemini-3.1-flash-tts-preview",
      "gemini-2.5-flash-preview-tts",
      "gemini-2.5-pro-preview-tts",
    ])
  );

  const geminiConfig = {
    responseModalities: ["AUDIO"],
    speechConfig: {
      voiceConfig: {
        prebuiltVoiceConfig: {
          voiceName: profile.voiceName,
        },
      },
    },
  };

  for (const model of audioModels) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [
                {
                  text: `${profile.styleInstruction}:\n\n"${cleanText}"`,
                },
              ],
            },
          ],
          generationConfig: geminiConfig,
        }),
        signal: controller.signal,
      });

      if (!res.ok) {
        const errSnippet = (await res.text()).slice(0, 160);
        console.warn(`[gemini-tts] ${model} HTTP ${res.status}: ${errSnippet}`);
        continue;
      }

      const json = await res.json();
      const parts = json.candidates?.[0]?.content?.parts || [];
      for (const p of parts) {
        const inline = p.inlineData || p.inline_data;
        if (inline?.data) {
          const mime = String(inline.mimeType || inline.mime_type || "").toLowerCase();
          if (mime.includes("mp3") || mime.includes("mpeg") || mime.includes("wav")) {
            return inline.data;
          }
          const rate = parseSampleRateFromMime(mime, 24000);
          return wrapPcm16ToWavBase64(inline.data, rate);
        }
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      console.warn(`[gemini-tts] ${model} failed: ${msg}`);
    } finally {
      clearTimeout(timer);
    }
  }

  return null;
}
