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
}: {
  systemInstruction?: string;
  contents: GeminiMessage[];
  temperature?: number;
  responseSchema?: Record<string, unknown>;
}) {
  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    throw new ApiError("GEMINI_API_KEY environment variable is not configured", 500, "MISSING_AI_KEY");
  }

  const preferredModel = Deno.env.get("GEMINI_MODEL") || "gemini-3.5-flash";
  const modelCandidates = Array.from(
    new Set([
      "gemini-3.5-flash",
      "gemini-3.6-flash",
      "gemini-3.7-flash",
      preferredModel,
      "gemini-3.8-flash",
      "gemini-flash-latest",
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

  const hasMultimodalImage = normalizedContents.some((m) =>
    m.parts.some((p: any) => Boolean(p.inline_data))
  );

  const buildRequestBody = (includeSchema: boolean) => {
    const body: any = {
      contents: normalizedContents,
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
