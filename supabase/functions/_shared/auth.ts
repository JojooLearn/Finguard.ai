// supabase/functions/_shared/auth.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

export interface AuthenticatedUser {
  id: string;
  email?: string;
}

export async function getAuthenticatedUser(req: Request): Promise<{ user: AuthenticatedUser | null; supabaseClient: any; error: string | null }> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return { user: null, supabaseClient: null, error: "Missing Authorization header" };
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const client = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) {
    return { user: null, supabaseClient: null, error: error?.message ?? "Invalid user token" };
  }

  return { user: { id: user.id, email: user.email }, supabaseClient: client, error: null };
}
