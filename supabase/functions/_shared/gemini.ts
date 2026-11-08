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
}: {
  systemInstruction?: string;
  contents: GeminiMessage[];
  temperature?: number;
  responseSchema?: Record<string, unknown>;
  responseModalities?: string[];
  speechConfig?: Record<string, unknown>;
}) {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new ApiError("GEMINI_API_KEY environment variable is not configured", 500, "MISSING_AI_KEY");
  }

  const envModel = Deno.env.get("GEMINI_MODEL");
  const modelCandidates = Array.from(
    new Set([
      ...(envModel ? [envModel] : []),
      "gemini-2.0-flash",
      "gemini-1.5-flash",
      "gemini-2.5-flash",
      "gemini-1.5-pro",
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

  const hasMultimodalImage = sanitizedContents.some((m) =>
    m.parts.some((p: any) => Boolean(p.inline_data))
  );

  const buildRequestBody = (includeSchema: boolean) => {
    const body: any = {
      contents: sanitizedContents,
      generationConfig: {
        temperature,
      },
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

  let lastError = "";
  for (const model of modelCandidates) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    try {
      let res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(buildRequestBody(true)),
      });

      // If multimodal + responseSchema triggered 400 on a specific model, retry with JSON mimeType only
      if (!res.ok && res.status === 400 && hasMultimodalImage && responseSchema) {
        res = await fetch(url, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(buildRequestBody(false)),
        });
      }

      if (!res.ok) {
        lastError = `${model} (${res.status}) - ${await res.text()}`;
        // Always try the next candidate model
        continue;
      }

      const json = await res.json();
      const candidate = json.candidates?.[0];
      const responseText = candidate?.content?.parts?.[0]?.text;
      if (responseText) return responseText;
    } catch (err: any) {
      lastError = err?.message || String(err);
    }
  }

  throw new ApiError(`All Gemini models failed: ${lastError}`, 502, "AI_GATEWAY_ERROR");
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

/**
 * Generates contextual AI Voice-Out (Gemini AUDIO modality / TTS) when request_audio === true.
 */
export async function generateGeminiSpeechAudio(
  textToSpeak: string,
  voiceName = "Puck"
): Promise<string | null> {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey || !textToSpeak || textToSpeak.trim().length === 0) return null;

  const cleanText = textToSpeak
    .replace(/[*#_`~]/g, "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 700);

  const audioModels = [
    "gemini-2.0-flash",
    "gemini-2.5-flash",
  ];

  // Configure Gemini with responseModalities & speechConfig per feature spec
  const geminiConfig = {
    responseModalities: ["AUDIO"],
    speechConfig: {
      voiceConfig: {
        prebuiltVoiceConfig: {
          voiceName,
        },
      },
    },
  };

  for (const model of audioModels) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
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
                  text: `Bacakan balasan Coach keuangan ini dengan nada santai dan natural dalam Bahasa Indonesia: "${cleanText}"`,
                },
              ],
            },
          ],
          generationConfig: geminiConfig,
        }),
      });

      if (!res.ok) continue;
      const json = await res.json();
      const parts = json.candidates?.[0]?.content?.parts || [];
      for (const p of parts) {
        const inline = p.inlineData || p.inline_data;
        if (inline?.data) {
          const mime = String(inline.mimeType || inline.mime_type || "").toLowerCase();
          if (mime.includes("pcm") || mime.includes("l16") || !mime.includes("mp3")) {
            return wrapPcm16ToWavBase64(inline.data, 24000);
          }
          return inline.data;
        }
      }
    } catch (_) {
      // Try next audio candidate model
    }
  }

  return null;
}
