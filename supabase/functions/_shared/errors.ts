// supabase/functions/_shared/errors.ts
import { corsHeaders } from "./cors.ts";

export class ApiError extends Error {
  statusCode: number;
  code: string;

  constructor(message: string, statusCode = 400, code = "BAD_REQUEST") {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
  }
}

export function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export function errorResponse(error: unknown) {
  if (error instanceof ApiError) {
    return jsonResponse({ error: error.message, code: error.code }, error.statusCode);
  }
  const message = error instanceof Error ? error.message : "Internal server error";
  return jsonResponse({ error: message, code: "INTERNAL_ERROR" }, 500);
}
