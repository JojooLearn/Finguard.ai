// supabase/functions/_shared/groq.ts
import { ApiError } from "./errors.ts";

export interface GroqMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

/**
 * Invokes Groq's OpenAI-compatible Chat Completions endpoint as the ultra-fast Primary AI Engine.
 * Enforces a strict timeout (default 4000ms) via AbortController so the caller's Circuit Breaker
 * can fail over cleanly to Gemini Backup Engine without exposing errors to clients.
 */
export async function callGroq({
  systemInstruction,
  messages,
  temperature = 0.2,
  jsonMode = true,
  timeoutMs = 4000,
  maxTokens = 1500,
}: {
  systemInstruction?: string;
  messages: GroqMessage[];
  temperature?: number;
  jsonMode?: boolean;
  timeoutMs?: number;
  maxTokens?: number;
}): Promise<string> {
  const apiKey = Deno.env.get("GROQ_API_KEY");
  if (!apiKey || apiKey.trim() === "") {
    throw new ApiError(
      "GROQ_API_KEY environment variable is not configured",
      500,
      "MISSING_GROQ_KEY"
    );
  }

  // Prioritize high-TPM Indonesian-capable model first; fall back automatically on 413/429/400/404.
  const envModel = Deno.env.get("GROQ_MODEL")?.trim();
  const modelCandidates = Array.from(
    new Set([
      ...(envModel ? [envModel] : []),
      "llama-3.3-70b-versatile",
      "qwen/qwen3.8-27b",
      "llama-3.1-8b-instant",
    ])
  );

  const payloadMessages: GroqMessage[] = [];
  if (systemInstruction && systemInstruction.trim().length > 0) {
    payloadMessages.push({
      role: "system",
      content: systemInstruction,
    });
  }

  for (const msg of messages) {
    if (!msg.content || msg.content.trim().length === 0) continue;
    if (
      payloadMessages.length > 0 &&
      payloadMessages[payloadMessages.length - 1].role === msg.role &&
      msg.role !== "system"
    ) {
      payloadMessages[payloadMessages.length - 1].content += `\n${msg.content}`;
    } else {
      payloadMessages.push({
        role: msg.role,
        content: msg.content,
      });
    }
  }

  if (!payloadMessages.some((m) => m.role === "user")) {
    payloadMessages.push({ role: "user", content: "Halo Coach FinGuard!" });
  }

  const deadline = Date.now() + timeoutMs;
  let lastError: Error | null = null;

  for (const model of modelCandidates) {
    const remainingMs = deadline - Date.now();
    if (remainingMs < 1000) break;

    const requestBody: Record<string, unknown> = {
      model,
      messages: payloadMessages,
      temperature,
      max_tokens: maxTokens,
    };

    if (jsonMode) {
      requestBody.response_format = { type: "json_object" };
    }

    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), remainingMs);

    try {
      const res = await fetch("https://api.groq.com/openai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey.trim()}`,
        },
        body: JSON.stringify(requestBody),
        signal: controller.signal,
      });

      if (!res.ok) {
        const errText = await res.text();
        lastError = new ApiError(
          `Groq ${model} error (${res.status}): ${errText.slice(0, 220)}`,
          res.status,
          res.status === 429 || res.status === 413 ? "GROQ_RATE_LIMIT" : "GROQ_HTTP_ERROR"
        );
        // Retry next Groq model immediately on TPM/rate limits, bad model, or JSON format fallback
        if (res.status === 413 || res.status === 429 || res.status === 404 || res.status === 400 || res.status >= 500) {
          continue;
        }
        throw lastError;
      }

      const json = await res.json();
      const content = json.choices?.[0]?.message?.content;
      if (!content || typeof content !== "string" || content.trim().length === 0) {
        lastError = new Error(`Groq ${model} returned empty completion content`);
        continue;
      }

      return content;
    } catch (err: any) {
      if (err?.name === "AbortError") {
        lastError = new ApiError(
          `Groq API timed out after ${timeoutMs}ms`,
          504,
          "GROQ_TIMEOUT"
        );
        break;
      }
      lastError = err instanceof Error ? err : new Error(String(err));
      if (err instanceof ApiError && err.statusCode === 401) {
        throw err;
      }
    } finally {
      clearTimeout(timeoutId);
    }
  }

  throw lastError ?? new ApiError("All Groq models failed", 502, "GROQ_HTTP_ERROR");
}
