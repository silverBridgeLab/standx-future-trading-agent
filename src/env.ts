import "dotenv/config";

export const CHAIN = (process.env.STANDX_CHAIN ?? "bsc").toLowerCase() as "bsc" | "solana";
export const WALLET_ADDRESS = process.env.STANDX_WALLET_ADDRESS ?? "";
export const STANDX_JWT = process.env.STANDX_JWT ?? "";

const RAW_SYMBOL = (process.env.SYMBOL ?? "BTC-USD").toUpperCase();

export function normalizeStandxSymbol(symbol: string): string {
  const s = symbol.toUpperCase().replace(/_/g, "-");
  if (s.includes("-")) return s;
  if (s.endsWith("USD")) return `${s.slice(0, -3)}-USD`;
  return s;
}

export const SYMBOL = normalizeStandxSymbol(RAW_SYMBOL);
export const LEVERAGE = Math.min(20, Math.max(1, parseInt(process.env.LEVERAGE ?? "10", 10)));
export const MARGIN_MODE = (process.env.MARGIN_MODE ?? "cross") as "cross" | "isolated";

export const AGENT_POLL_MS = Math.max(2000, parseInt(process.env.AGENT_POLL_MS ?? "60000", 10));
export const AGENT_DRY_RUN = process.env.AGENT_DRY_RUN === "true";
export const AGENT_MODE = (process.env.AGENT_MODE ?? "hybrid") as "ai" | "rules" | "hybrid";

export const AI_API_KEY = process.env.AI_API_KEY ?? process.env.OPENAI_API_KEY ?? "";
export const AI_BASE_URL = (process.env.AI_BASE_URL ?? "https://api.openai.com/v1").replace(/\/$/, "");
export const AI_MODEL = process.env.AI_MODEL ?? "gpt-4o-mini";
export const AI_MIN_CONFIDENCE = Math.min(
  1,
  Math.max(0, parseFloat(process.env.AI_MIN_CONFIDENCE ?? "0.55"))
);

export const RISK_MAX_NOTIONAL = parseFloat(process.env.RISK_MAX_NOTIONAL ?? "1000");
export const RISK_PCT = Math.min(100, Math.max(0.1, parseFloat(process.env.RISK_PCT ?? "2")));
export const SESSION_ID = process.env.STANDX_SESSION_ID ?? "standx-agent-session";
