// supabase/functions/_shared/validation.ts
export function validateUUID(id: string): boolean {
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  return uuidRegex.test(id);
}

export function sanitizeText(text: string, maxLength = 1000): string {
  if (!text) return "";
  return text.trim().slice(0, maxLength);
}
