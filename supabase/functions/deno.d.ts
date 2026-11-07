// Type declarations for Deno runtime & URL imports in Supabase Edge Functions
// This file resolves VS Code TypeScript language server warnings (ts2307 & ts2304)

declare const Deno: {
  env: {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    toObject(): Record<string, string>;
  };
  [key: string]: any;
};

declare module "https://*" {
  export const serve: (handler: (req: Request) => Promise<Response> | Response) => void;
  export const createClient: (url: string, key: string, options?: any) => any;
  export const corsHeaders: Record<string, string>;
  const content: any;
  export default content;
}

declare module "http://*" {
  const content: any;
  export default content;
}

declare module "npm:*" {
  const content: any;
  export default content;
  export const RSI: any;
  export const SMA: any;
  export const MACD: any;
}

