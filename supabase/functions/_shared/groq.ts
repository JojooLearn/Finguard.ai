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

  // Note: Groq decommissioned legacy `llama3-8b-8192`; default to active ultra-fast `qwen/qwen3.8-27b`
  // (also overridable at runtime via `GROQ_MODEL` Supabase secret).
  const model = Deno.env.get("GROQ_MODEL")?.trim() || "qwen/qwen3.8-27b";

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
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

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
      throw new ApiError(
        `Groq API error (${res.status}): ${errText.slice(0, 300)}`,
        res.status,
        res.status === 429 ? "GROQ_RATE_LIMIT" : "GROQ_HTTP_ERROR"
      );
    }

    const json = await res.json();
    const content = json.choices?.[0]?.message?.content;
    if (!content || typeof content !== "string" || content.trim().length === 0) {
      throw new Error("Groq returned empty completion content");
    }

    return content;
  } catch (err: any) {
    if (err?.name === "AbortError") {
      throw new ApiError(
        `Groq API timed out after ${timeoutMs}ms`,
        504,
        "GROQ_TIMEOUT"
      );
    }
    throw err;
  } finally {
    clearTimeout(timeoutId);
  }
}
