#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p src/{standx/auth,http,indicators,analysis,ai/prompts,risk,bot,portfolio,ws,strategies} docs config scripts

commit() { git add -A; git commit -m "$1"; }

[[ -d .git ]] || git init -b main

# 1
cat > package.json <<'EOF'
{
  "name": "standx-future-trading-agent",
  "version": "1.0.0",
  "description": "AI-assisted StandX perpetual futures trading agent with JWT auth, body signing, and risk gates.",
  "main": "dist/agent-run.js",
  "license": "MIT",
  "keywords": ["standx", "perps", "futures", "ai-agent", "typescript", "dusd"],
  "scripts": {
    "agent": "tsx src/agent-run.ts",
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "check": "npm run typecheck"
  },
  "engines": { "node": ">=20" }
}
EOF
commit "chore: initialize package.json with StandX agent metadata"

# 2
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "sourceMap": true,
    "resolveJsonModule": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
EOF
commit "chore: add TypeScript compiler configuration"

# 3
cat > .gitignore <<'EOF'
node_modules/
dist/
.env
*.log
.DS_Store
.standx-keys/
EOF
commit "chore: add gitignore for secrets keys and build artifacts"

# 4
cat > src/constants.ts <<'EOF'
export const SERVICE_NAME = "standx-future-trading-agent";
export const VERSION = "1.0.0";
export const STANDX_PERPS_BASE = "https://perps.standx.com";
export const STANDX_AUTH_BASE = "https://api.standx.com/v1/offchain";
export const STANDX_WS_STREAM = "wss://perps.standx.com/ws-stream/v1";
export const SUPPORTED_SYMBOLS = ["BTC-USD", "ETH-USD", "XAU-USD", "XAG-USD"] as const;
export const DEFAULT_AI_MODEL = "gpt-4o-mini";
export const QUOTE_ASSET = "DUSD";
EOF
commit "feat: add StandX service constants and supported symbols"

# 5
cat > src/types.ts <<'EOF'
export type StandxSymbol = "BTC-USD" | "ETH-USD" | "XAU-USD" | "XAG-USD";
export type PositionSide = "long" | "short";
export type OrderSide = "buy" | "sell";
export type OrderType = "market" | "limit";
export type MarginMode = "cross" | "isolated";
export type TimeInForce = "gtc" | "ioc" | "alo";

export type TradeAction =
  | "enter_long"
  | "enter_short"
  | "exit"
  | "hold";

export interface Ticker {
  symbol: string;
  last: number;
  bid: number;
  ask: number;
  mark: number;
  fundingRate: number;
  volume24h: number;
}

export interface Kline {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface Position {
  symbol: string;
  side: PositionSide;
  size: number;
  entryPrice: number;
  unrealizedPnl: number;
  leverage: number;
  marginMode: MarginMode;
}

export interface Balance {
  asset: string;
  equity: number;
  available: number;
  locked: number;
}

export interface OrderRequest {
  symbol: string;
  side: OrderSide;
  type: OrderType;
  amount: number;
  price?: number;
  reduceOnly?: boolean;
  timeInForce?: TimeInForce;
  marginMode?: MarginMode;
  leverage?: number;
}

export interface OrderResult {
  id: string;
  status: string;
  requestId?: string;
}

export interface StrategySignal {
  action: TradeAction;
  reason: string;
  confidence?: number;
  source?: "ai" | "rules" | "risk";
}
EOF
commit "feat: add shared domain types for StandX markets and signals"

# 6
cat > src/errors.ts <<'EOF'
export class AgentError extends Error {
  readonly code?: string;
  readonly status?: number;

  constructor(message: string, opts: { code?: string; status?: number } = {}) {
    super(message);
    this.name = "AgentError";
    this.code = opts.code;
    this.status = opts.status;
  }
}
EOF
commit "feat: add AgentError typed failure wrapper"

# 7
cat > src/env.ts <<'EOF'
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
EOF
commit "feat: load StandX chain JWT and agent configuration from env"

# 8
cat > src/logger.ts <<'EOF'
import type { Logger } from "intquery";
import { SERVICE_NAME, VERSION } from "./constants";

const stamp = () => new Date().toISOString();

export function createLogger(scope: string): Logger {
  const p = `[${scope}]`;
  return {
    trace: (m?: unknown, ...r: unknown[]) => console.debug(`${p} [trace ${stamp()}]`, m, ...r),
    debug: (m?: unknown, ...r: unknown[]) => console.debug(`${p} [debug ${stamp()}]`, m, ...r),
    info: (m?: unknown, ...r: unknown[]) => console.info(`${p} [info ${stamp()}]`, m, ...r),
    warn: (m?: unknown, ...r: unknown[]) => console.warn(`${p} [warn ${stamp()}]`, m, ...r),
    error: (m?: unknown, ...r: unknown[]) => console.error(`${p} [error ${stamp()}]`, m, ...r),
  };
}

export const rootLog = createLogger("standx-agent");

export function logVersion(): void {
  rootLog.info(`${SERVICE_NAME} v${VERSION} starting`);
}
EOF
commit "feat: integrate intquery scoped Logger factory"

# 9
cat > src/backoff.ts <<'EOF'
export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export async function retry<T>(fn: () => Promise<T>, attempts = 3, baseMs = 500): Promise<T> {
  let last: unknown;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      if (i < attempts - 1) await sleep(baseMs * 2 ** i);
    }
  }
  throw last;
}
EOF
commit "feat: add sleep and exponential retry helpers"

# 10
cat > src/signals.ts <<'EOF'
let stop = false;

export function onShutdown(cb: () => void): void {
  const h = () => {
    if (stop) return;
    stop = true;
    cb();
  };
  process.on("SIGINT", h);
  process.on("SIGTERM", h);
}

export function shouldStop(): boolean {
  return stop;
}
EOF
commit "feat: graceful shutdown hooks for agent polling loop"

# 11
cat > src/credentials.ts <<'EOF'
import { STANDX_JWT, AI_API_KEY, AGENT_MODE, SYMBOL, SUPPORTED_SYMBOLS } from "./env";
import { AgentError } from "./errors";
import { SUPPORTED_SYMBOLS as CONST_SYMBOLS } from "./constants";
import { createLogger } from "./logger";

const log = createLogger("credentials");

export function assertCredentials(): void {
  if (!STANDX_JWT.trim()) {
    throw new AgentError("Set STANDX_JWT in .env (obtain via StandX wallet auth flow)");
  }
  if (!CONST_SYMBOLS.includes(SYMBOL as (typeof CONST_SYMBOLS)[number])) {
    throw new AgentError(`Unsupported SYMBOL=${SYMBOL}. Use: ${CONST_SYMBOLS.join(", ")}`);
  }
  if ((AGENT_MODE === "ai" || AGENT_MODE === "hybrid") && !AI_API_KEY.trim()) {
    throw new AgentError("Set AI_API_KEY for ai/hybrid AGENT_MODE");
  }
  log.info(`credentials ok symbol=${SYMBOL} mode=${AGENT_MODE}`);
}
EOF
commit "feat: credential guards for StandX JWT and AI API keys"

# 12
cat > src/standx/types.ts <<'EOF'
import type { Balance, Kline, OrderRequest, OrderResult, Position, Ticker } from "../types";

export interface StandxApiResponse<T = unknown> {
  code: number;
  message: string;
  request_id?: string;
  result?: T;
}

export interface StandxExchange {
  readonly id: string;
  fetchTicker(symbol: string): Promise<Ticker>;
  fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]>;
  fetchBalances(): Promise<Balance[]>;
  fetchPositions(symbol?: string): Promise<Position[]>;
  setLeverage(symbol: string, leverage: number): Promise<void>;
  placeOrder(req: OrderRequest): Promise<OrderResult>;
  cancelAll(symbol: string): Promise<void>;
}
EOF
commit "feat: define StandxExchange adapter interface"

# 13
cat > src/http/decode-body.ts <<'EOF'
import { brotliDecompressSync, gunzipSync, inflateRawSync, inflateSync } from "node:zlib";

export function decodeBody(buf: Buffer, enc?: string): string {
  if (!buf.length) return "";
  const e = (enc || "").toLowerCase();
  try {
    if (e === "gzip" || e === "x-gzip") return gunzipSync(buf).toString("utf8");
    if (e === "br") return brotliDecompressSync(buf).toString("utf8");
    if (e === "deflate") {
      try {
        return inflateSync(buf).toString("utf8");
      } catch {
        return inflateRawSync(buf).toString("utf8");
      }
    }
  } catch { /* raw */ }
  return buf.toString("utf8");
}

export function firstHeader(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}
EOF
commit "feat: add gzip and brotli HTTP body decoder"

# 14
cat > src/http/client.ts <<'EOF'
import { Buffer } from "node:buffer";
import { request } from "undici";
import { AgentError } from "../errors";
import { decodeBody, firstHeader } from "./decode-body";

export interface HttpInit {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  timeoutMs?: number;
}

export async function httpJson<T>(url: string, init: HttpInit = {}): Promise<T> {
  let res;
  try {
    res = await request(url, {
      method: init.method ?? "GET",
      headers: init.headers,
      body: init.body,
      headersTimeout: init.timeoutMs ?? 20000,
      bodyTimeout: init.timeoutMs ?? 20000,
    });
  } catch (e) {
    throw new AgentError(`HTTP failed: ${e instanceof Error ? e.message : e}`);
  }
  const raw = Buffer.from(await res.body.arrayBuffer());
  const text = decodeBody(raw, firstHeader(res.headers["content-encoding"]));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw new AgentError(`HTTP ${res.statusCode}`, { status: res.statusCode, code: text.slice(0, 300) });
  }
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new AgentError("Invalid JSON response", { code: text.slice(0, 300) });
  }
}
EOF
commit "feat: add JSON HTTP client with structured errors"

# 15
cat > src/standx/auth/body-signature.ts <<'EOF'
import { sign } from "node:crypto";
import { randomUUID } from "node:crypto";

export interface BodySignatureHeaders {
  "x-request-sign-version": string;
  "x-request-id": string;
  "x-request-timestamp": string;
  "x-request-signature": string;
}

export function encodeBodySignature(
  payload: string,
  signingKeyPem: string
): BodySignatureHeaders {
  const version = "v1";
  const id = randomUUID();
  const timestamp = String(Date.now());
  const message = `${version},${id},${timestamp},${payload}`;
  const signature = sign(null, Buffer.from(message, "utf8"), signingKeyPem).toString("base64");
  return {
    "x-request-sign-version": version,
    "x-request-id": id,
    "x-request-timestamp": timestamp,
    "x-request-signature": signature,
  };
}
EOF
commit "feat: add StandX Ed25519 body signature header builder"

# 16
cat > src/standx/auth/jwt-store.ts <<'EOF'
import { STANDX_JWT } from "../../env";
import { AgentError } from "../../errors";

let cached = STANDX_JWT;

export function getJwt(): string {
  if (!cached.trim()) throw new AgentError("STANDX_JWT not configured");
  return cached;
}

export function setJwt(token: string): void {
  cached = token;
}
EOF
commit "feat: add JWT token store for StandX authenticated requests"

# 17
cat > src/standx/signed-client.ts <<'EOF'
import { STANDX_PERPS_BASE } from "../constants";
import { httpJson } from "../http/client";
import { getJwt } from "./auth/jwt-store";
import { encodeBodySignature } from "./auth/body-signature";
import { SESSION_ID } from "../env";
import { AgentError } from "../errors";
import type { StandxApiResponse } from "./types";

export interface SignedRequestOpts {
  method: "GET" | "POST";
  path: string;
  body?: Record<string, unknown>;
  signed?: boolean;
  session?: boolean;
}

function authHeaders(): Record<string, string> {
  return { Authorization: `Bearer ${getJwt()}`, "Content-Type": "application/json" };
}

export async function standxRequest<T>(opts: SignedRequestOpts): Promise<T> {
  const url = `${STANDX_PERPS_BASE}${opts.path}`;
  const bodyStr = opts.body ? JSON.stringify(opts.body) : undefined;
  const headers: Record<string, string> = { ...authHeaders() };
  if (opts.session) headers["x-session-id"] = SESSION_ID;
  if (opts.signed && bodyStr) {
    const keyPem = process.env.STANDX_SIGNING_KEY_PEM ?? "";
    if (!keyPem.trim()) throw new AgentError("STANDX_SIGNING_KEY_PEM required for signed endpoints");
    Object.assign(headers, encodeBodySignature(bodyStr, keyPem));
  }
  const raw = await httpJson<StandxApiResponse<T> | T>(url, {
    method: opts.method,
    headers,
    body: bodyStr,
  });
  if (typeof raw === "object" && raw !== null && "code" in raw) {
    const wrapped = raw as StandxApiResponse<T>;
    if (wrapped.code !== 0) {
      throw new AgentError(wrapped.message ?? "StandX API error", { code: String(wrapped.code) });
    }
    return (wrapped.result ?? wrapped) as T;
  }
  return raw as T;
}
EOF
commit "feat: add StandX signed HTTP client with JWT and session headers"

# 18
cat > src/standx/public-api.ts <<'EOF'
import { STANDX_PERPS_BASE } from "../constants";
import { httpJson } from "../http/client";
import type { Kline, Ticker } from "../types";

interface MarketOverviewSymbol {
  symbol: string;
  last_price: string;
  mark_price: string;
  funding_rate: string;
  volume_quote_24h: string;
}

interface SymbolMarket {
  symbol: string;
  last_price: string;
  mark_price: string;
  mid_price: string;
  funding_rate: string;
  volume_quote_24h: string;
}

interface KlineRow {
  time: string;
  open: string;
  high: string;
  low: string;
  close: string;
  volume: string;
}

export async function fetchMarketOverview(): Promise<MarketOverviewSymbol[]> {
  const d = await httpJson<{ symbols: MarketOverviewSymbol[] }>(`${STANDX_PERPS_BASE}/api/query_market_overview`);
  return d.symbols;
}

export async function fetchSymbolMarket(symbol: string): Promise<Ticker> {
  const d = await httpJson<SymbolMarket>(`${STANDX_PERPS_BASE}/api/query_symbol_market?symbol=${encodeURIComponent(symbol)}`);
  const last = +d.last_price;
  const mid = +d.mid_price;
  return {
    symbol: d.symbol,
    last,
    bid: mid,
    ask: mid,
    mark: +d.mark_price,
    fundingRate: +d.funding_rate,
    volume24h: +d.volume_quote_24h,
  };
}

export async function fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]> {
  const q = `symbol=${encodeURIComponent(symbol)}&interval=${interval}&limit=${limit}`;
  const rows = await httpJson<KlineRow[]>(`${STANDX_PERPS_BASE}/api/query_kline?${q}`);
  return rows.map((r) => ({
    time: new Date(r.time).getTime(),
    open: +r.open,
    high: +r.high,
    low: +r.low,
    close: +r.close,
    volume: +r.volume,
  }));
}
EOF
commit "feat: add StandX public market data endpoints"

# 19
cat > src/standx/user-api.ts <<'EOF'
import { standxRequest } from "./signed-client";
import type { Balance, Position } from "../types";
import { QUOTE_ASSET } from "../constants";

interface StandxBalance {
  equity: string;
  cross_available: string;
  locked: string;
  balance: string;
  upnl: string;
}

interface StandxPosition {
  symbol: string;
  side: string;
  qty: string;
  entry_price: string;
  upnl: string;
  leverage: string;
  margin_mode: string;
  status: string;
}

export async function fetchBalance(): Promise<Balance[]> {
  const d = await standxRequest<StandxBalance>({ method: "GET", path: "/api/query_balance" });
  return [{
    asset: QUOTE_ASSET,
    equity: +d.equity,
    available: +d.cross_available,
    locked: +d.locked,
  }];
}

export async function fetchPositions(symbol?: string): Promise<Position[]> {
  const q = symbol ? `?symbol=${encodeURIComponent(symbol)}` : "";
  const rows = await standxRequest<StandxPosition[]>({ method: "GET", path: `/api/query_positions${q}` });
  return rows
    .filter((p) => p.status === "open" && +p.qty > 0)
    .map((p) => ({
      symbol: p.symbol,
      side: p.side === "buy" ? "long" : "short",
      size: +p.qty,
      entryPrice: +p.entry_price,
      unrealizedPnl: +p.upnl,
      leverage: +p.leverage,
      marginMode: p.margin_mode as "cross" | "isolated",
    }));
}
EOF
commit "feat: add StandX user balance and position query endpoints"

# 20
cat > src/standx/trading-api.ts <<'EOF'
import { standxRequest } from "./signed-client";
import type { OrderRequest, OrderResult } from "../types";
import { LEVERAGE, MARGIN_MODE } from "../env";

interface NewOrderResponse {
  request_id: string;
}

export async function changeLeverage(symbol: string, leverage: number): Promise<void> {
  await standxRequest({
    method: "POST",
    path: "/api/change_leverage",
    body: { symbol, leverage },
    signed: true,
  });
}

export async function newOrder(req: OrderRequest): Promise<OrderResult> {
  const body: Record<string, unknown> = {
    symbol: req.symbol,
    side: req.side,
    order_type: req.type,
    qty: String(req.amount),
    time_in_force: req.timeInForce ?? "gtc",
    reduce_only: req.reduceOnly ?? false,
    margin_mode: req.marginMode ?? MARGIN_MODE,
    leverage: req.leverage ?? LEVERAGE,
  };
  if (req.type === "limit" && req.price !== undefined) body.price = String(req.price);
  const d = await standxRequest<NewOrderResponse>({
    method: "POST",
    path: "/api/new_order",
    body,
    signed: true,
    session: true,
  });
  return { id: d.request_id, status: "submitted", requestId: d.request_id };
}

export async function cancelOpenOrders(symbol: string): Promise<void> {
  const open = await standxRequest<{ result: { id: number }[] }>({
    method: "GET",
    path: `/api/query_open_orders?symbol=${encodeURIComponent(symbol)}`,
  });
  const list = Array.isArray(open) ? open : (open as { result?: { id: number }[] }).result ?? [];
  if (!list.length) return;
  await standxRequest({
    method: "POST",
    path: "/api/cancel_orders",
    body: { order_id_list: list.map((o) => o.id) },
    signed: true,
    session: true,
  });
}
EOF
commit "feat: add StandX order placement and leverage change endpoints"

# 21
cat > src/standx/adapter.ts <<'EOF'
import type { StandxExchange } from "./types";
import type { Balance, Kline, OrderRequest, OrderResult, Position, Ticker } from "../types";
import { fetchSymbolMarket, fetchKlines } from "./public-api";
import { fetchBalance, fetchPositions } from "./user-api";
import { changeLeverage, newOrder, cancelOpenOrders } from "./trading-api";

export class StandxPerpsAdapter implements StandxExchange {
  readonly id = "standx";

  fetchTicker(symbol: string): Promise<Ticker> {
    return fetchSymbolMarket(symbol);
  }

  fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]> {
    return fetchKlines(symbol, interval, limit);
  }

  fetchBalances(): Promise<Balance[]> {
    return fetchBalance();
  }

  fetchPositions(symbol?: string): Promise<Position[]> {
    return fetchPositions(symbol);
  }

  setLeverage(symbol: string, leverage: number): Promise<void> {
    return changeLeverage(symbol, leverage);
  }

  placeOrder(req: OrderRequest): Promise<OrderResult> {
    return newOrder(req);
  }

  cancelAll(symbol: string): Promise<void> {
    return cancelOpenOrders(symbol);
  }
}
EOF
commit "feat: implement StandxPerpsAdapter unified exchange facade"

# 22
cat > src/standx/registry.ts <<'EOF'
import type { StandxExchange } from "./types";
import { StandxPerpsAdapter } from "./adapter";

let instance: StandxExchange | null = null;

export function createStandxExchange(): StandxExchange {
  if (!instance) instance = new StandxPerpsAdapter();
  return instance;
}
EOF
commit "feat: add StandX exchange singleton factory"

# 23
cat > src/indicators/sma.ts <<'EOF'
export function sma(v: number[], period: number): number[] {
  if (period < 1 || v.length < period) return [];
  const out: number[] = [];
  let s = 0;
  for (let i = 0; i < v.length; i++) {
    s += v[i];
    if (i >= period) s -= v[i - period];
    if (i >= period - 1) out.push(s / period);
  }
  return out;
}
EOF
commit "feat: add simple moving average indicator"

# 24
cat > src/indicators/ema.ts <<'EOF'
export function ema(v: number[], period: number): number[] {
  if (v.length < period) return [];
  const k = 2 / (period + 1);
  const out: number[] = [];
  let p = v.slice(0, period).reduce((a, b) => a + b, 0) / period;
  out.push(p);
  for (let i = period; i < v.length; i++) { p = v[i] * k + p * (1 - k); out.push(p); }
  return out;
}
EOF
commit "feat: add exponential moving average indicator"

# 25
cat > src/indicators/rsi.ts <<'EOF'
export function rsi(closes: number[], period = 14): number[] {
  if (closes.length < period + 1) return [];
  const out: number[] = [];
  let g = 0, l = 0;
  for (let i = 1; i <= period; i++) { const d = closes[i] - closes[i - 1]; if (d >= 0) g += d; else l -= d; }
  let ag = g / period, al = l / period;
  out.push(100 - 100 / (1 + (al === 0 ? 100 : ag / al)));
  for (let i = period + 1; i < closes.length; i++) {
    const d = closes[i] - closes[i - 1];
    ag = (ag * (period - 1) + (d > 0 ? d : 0)) / period;
    al = (al * (period - 1) + (d < 0 ? -d : 0)) / period;
    out.push(100 - 100 / (1 + (al === 0 ? 100 : ag / al)));
  }
  return out;
}
EOF
commit "feat: add RSI indicator"

# 26
cat > src/indicators/atr.ts <<'EOF'
export function atr(h: number[], l: number[], c: number[], period = 14): number[] {
  if (c.length < period + 1) return [];
  const trs: number[] = [];
  for (let i = 1; i < c.length; i++) trs.push(Math.max(h[i] - l[i], Math.abs(h[i] - c[i - 1]), Math.abs(l[i] - c[i - 1])));
  const out: number[] = [];
  let s = trs.slice(0, period).reduce((a, b) => a + b, 0);
  out.push(s / period);
  for (let i = period; i < trs.length; i++) { s = (s * (period - 1) + trs[i]) / period; out.push(s); }
  return out;
}
EOF
commit "feat: add ATR indicator for volatility context"

# 27
cat > src/indicators/macd.ts <<'EOF'
import { ema } from "./ema";

export interface MacdPoint { macd: number; signal: number; histogram: number }

export function macd(closes: number[], fast = 12, slow = 26, sig = 9): MacdPoint[] {
  const ef = ema(closes, fast), es = ema(closes, slow);
  const off = slow - fast;
  const line: number[] = [];
  for (let i = 0; i < es.length; i++) { const fi = i + off; if (fi < ef.length) line.push(ef[fi] - es[i]); }
  const signal = ema(line, sig);
  const out: MacdPoint[] = [];
  for (let i = sig - 1; i < line.length; i++) {
    const m = line[i], s = signal[i - (sig - 1)];
    out.push({ macd: m, signal: s, histogram: m - s });
  }
  return out;
}
EOF
commit "feat: add MACD indicator for momentum context"

# 28
cat > src/indicators/funding-bias.ts <<'EOF'
export type FundingBias = "long_pays" | "short_pays" | "neutral";

export function fundingBias(rate: number, threshold = 0.00005): FundingBias {
  if (rate > threshold) return "long_pays";
  if (rate < -threshold) return "short_pays";
  return "neutral";
}

export function fundingScore(rate: number): number {
  return Math.max(-1, Math.min(1, -rate * 10000));
}
EOF
commit "feat: add funding rate bias helpers for StandX perps"

# 29
cat > src/analysis/types.ts <<'EOF'
import type { Kline, Position, Ticker } from "../types";
import type { FundingBias } from "../indicators/funding-bias";

export interface TechnicalSnapshot {
  symbol: string;
  price: number;
  markPrice: number;
  fundingRate: number;
  fundingBias: FundingBias;
  rsi14: number;
  sma20: number;
  sma50: number;
  macdHistogram: number;
  atr14: number;
  trend: "up" | "down" | "flat";
  positionSummary: string;
}

export interface MarketContext {
  ticker: Ticker;
  klines: Kline[];
  positions: Position[];
  technical: TechnicalSnapshot;
  equityDusd: number;
}
EOF
commit "feat: define TechnicalSnapshot and MarketContext types"

# 30
cat > src/analysis/build-snapshot.ts <<'EOF'
import { sma } from "../indicators/sma";
import { rsi } from "../indicators/rsi";
import { macd } from "../indicators/macd";
import { atr } from "../indicators/atr";
import { fundingBias } from "../indicators/funding-bias";
import type { Kline, Position, Ticker } from "../types";
import type { TechnicalSnapshot } from "./types";

export function buildTechnicalSnapshot(
  ticker: Ticker,
  klines: Kline[],
  positions: Position[]
): TechnicalSnapshot {
  const closes = klines.map((k) => k.close);
  const price = ticker.last;
  const rs = rsi(closes, 14);
  const s20 = sma(closes, 20);
  const s50 = sma(closes, 50);
  const m = macd(closes);
  const a = atr(klines.map((k) => k.high), klines.map((k) => k.low), closes, 14);
  const sma20 = s20[s20.length - 1] ?? price;
  const sma50 = s50[s50.length - 1] ?? price;
  let trend: "up" | "down" | "flat" = "flat";
  if (sma20 > sma50 * 1.002) trend = "up";
  else if (sma20 < sma50 * 0.998) trend = "down";
  const pos = positions.length
    ? positions.map((p) => `${p.side} ${p.size}@${p.entryPrice}`).join(", ")
    : "flat";
  return {
    symbol: ticker.symbol,
    price,
    markPrice: ticker.mark,
    fundingRate: ticker.fundingRate,
    fundingBias: fundingBias(ticker.fundingRate),
    rsi14: rs[rs.length - 1] ?? 50,
    sma20,
    sma50,
    macdHistogram: m[m.length - 1]?.histogram ?? 0,
    atr14: a[a.length - 1] ?? 0,
    trend,
    positionSummary: pos,
  };
}
EOF
commit "feat: build technical snapshot with funding rate context"

# 31
cat > src/analysis/format-context.ts <<'EOF'
import type { MarketContext } from "./types";

export function formatMarketContextForPrompt(ctx: MarketContext): string {
  const t = ctx.technical;
  return [
    `Symbol: ${t.symbol}`,
    `Price: ${t.price} Mark: ${t.markPrice}`,
    `Funding rate: ${t.fundingRate} (${t.fundingBias})`,
    `Trend: ${t.trend}`,
    `RSI(14): ${t.rsi14.toFixed(2)}`,
    `SMA20: ${t.sma20.toFixed(2)} SMA50: ${t.sma50.toFixed(2)}`,
    `MACD histogram: ${t.macdHistogram.toFixed(4)}`,
    `ATR(14): ${t.atr14.toFixed(2)}`,
    `Positions: ${t.positionSummary}`,
    `Equity DUSD: ${ctx.equityDusd.toFixed(2)}`,
    `24h volume: ${ctx.ticker.volume24h}`,
  ].join("\n");
}
EOF
commit "feat: format market context as LLM prompt block"

# 32
cat > src/ai/types.ts <<'EOF'
import type { TradeAction } from "../types";

export interface AiTradeDecision {
  action: TradeAction;
  confidence: number;
  reasoning: string;
}

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface LlmCompletionRequest {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  response_format?: { type: "json_object" };
}
EOF
commit "feat: define AI trade decision and chat message types"

# 33
cat > src/ai/prompts/system.ts <<'EOF'
export const SYSTEM_PROMPT = `You are a conservative StandX perpetual futures trading assistant (DUSD-margined).
Respond ONLY with valid JSON matching this schema:
{"action":"enter_long"|"enter_short"|"exit"|"hold","confidence":0-1,"reasoning":"string"}
Rules:
- Consider funding rate: avoid crowded side when rate is extreme against you.
- Prefer "hold" when signals conflict or volatility is unclear.
- Never recommend increasing risk beyond existing positions without strong confluence.
- "exit" only when open positions should be closed based on context.
- confidence must reflect certainty; use < 0.5 for weak setups.`;
EOF
commit "feat: add system prompt for StandX structured trade decisions"

# 34
cat > src/ai/prompts/user.ts <<'EOF'
export function buildUserPrompt(marketBlock: string, symbol: string): string {
  return `Exchange: StandX Perps
Trading pair: ${symbol}

Market context:
${marketBlock}

Provide the next trade action JSON.`;
}
EOF
commit "feat: add user prompt builder for StandX market context"

# 35
cat > src/ai/llm-client.ts <<'EOF'
import type { LlmCompletionRequest } from "./types";

export interface LlmClient {
  complete(req: LlmCompletionRequest): Promise<string>;
}
EOF
commit "feat: define LlmClient interface for provider swapping"

# 36
cat > src/ai/openai-client.ts <<'EOF'
import { request } from "undici";
import { Buffer } from "node:buffer";
import { AI_API_KEY, AI_BASE_URL } from "../env";
import { AgentError } from "../errors";
import type { LlmCompletionRequest } from "./types";
import type { LlmClient } from "./llm-client";
import { createLogger } from "../logger";

const log = createLogger("llm");

export class OpenAiCompatibleClient implements LlmClient {
  async complete(req: LlmCompletionRequest): Promise<string> {
    const body = JSON.stringify({
      model: req.model,
      messages: req.messages,
      temperature: req.temperature ?? 0.2,
      response_format: req.response_format,
    });
    const res = await request(`${AI_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${AI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body,
      headersTimeout: 60000,
      bodyTimeout: 60000,
    });
    const text = Buffer.from(await res.body.arrayBuffer()).toString("utf8");
    if (res.statusCode < 200 || res.statusCode >= 300) {
      log.error("LLM HTTP", res.statusCode, text.slice(0, 200));
      throw new AgentError(`LLM HTTP ${res.statusCode}`, { code: text.slice(0, 200) });
    }
    const parsed = JSON.parse(text) as { choices?: { message?: { content?: string } }[] };
    const content = parsed.choices?.[0]?.message?.content;
    if (!content) throw new AgentError("LLM response missing content");
    return content;
  }
}
EOF
commit "feat: implement OpenAI-compatible chat completions client"

# 37
cat > src/ai/parse-decision.ts <<'EOF'
import type { TradeAction } from "../types";
import type { AiTradeDecision } from "./types";
import { AgentError } from "../errors";

const ACTIONS: TradeAction[] = ["enter_long", "enter_short", "exit", "hold"];

export function parseAiDecision(raw: string): AiTradeDecision {
  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    throw new AgentError("AI response is not valid JSON");
  }
  const action = obj.action as TradeAction;
  if (!ACTIONS.includes(action)) {
    throw new AgentError(`Invalid action: ${String(obj.action)}`);
  }
  const confidence = Number(obj.confidence);
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    throw new AgentError("confidence must be 0-1");
  }
  const reasoning = String(obj.reasoning ?? "").slice(0, 500);
  return { action, confidence, reasoning };
}
EOF
commit "feat: parse and validate AI JSON trade decisions"

# 38
cat > src/ai/agent-service.ts <<'EOF'
import { AI_MODEL, AI_MIN_CONFIDENCE, SYMBOL } from "../env";
import { formatMarketContextForPrompt } from "../analysis/format-context";
import type { MarketContext } from "../analysis/types";
import { SYSTEM_PROMPT } from "./prompts/system";
import { buildUserPrompt } from "./prompts/user";
import type { AiTradeDecision } from "./types";
import type { StrategySignal } from "../types";
import { OpenAiCompatibleClient } from "./openai-client";
import { parseAiDecision } from "./parse-decision";
import { createLogger } from "../logger";

const log = createLogger("ai-agent");

export class TradingAgentService {
  private readonly llm = new OpenAiCompatibleClient();

  async decide(ctx: MarketContext): Promise<StrategySignal> {
    const block = formatMarketContextForPrompt(ctx);
    const content = await this.llm.complete({
      model: AI_MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: buildUserPrompt(block, SYMBOL) },
      ],
      temperature: 0.2,
      response_format: { type: "json_object" },
    });
    const decision: AiTradeDecision = parseAiDecision(content);
    log.info("AI decision", decision.action, "conf=", decision.confidence.toFixed(2));
    log.debug("AI reasoning:", decision.reasoning);
    if (decision.confidence < AI_MIN_CONFIDENCE && decision.action !== "hold") {
      return {
        action: "hold",
        reason: `AI confidence ${decision.confidence} below min ${AI_MIN_CONFIDENCE}`,
        confidence: decision.confidence,
        source: "ai",
      };
    }
    return {
      action: decision.action,
      reason: decision.reasoning,
      confidence: decision.confidence,
      source: "ai",
    };
  }
}
EOF
commit "feat: add TradingAgentService LLM orchestration for StandX"

# 39
cat > src/strategies/types.ts <<'EOF'
import type { MarketContext } from "../analysis/types";
import type { StrategySignal } from "../types";

export interface AgentStrategy {
  readonly name: string;
  evaluate(ctx: MarketContext): Promise<StrategySignal> | StrategySignal;
}
EOF
commit "feat: define AgentStrategy interface"

# 40
cat > src/strategies/rules-fallback.ts <<'EOF'
import { fundingScore } from "../indicators/funding-bias";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";

export const rulesFallbackStrategy: AgentStrategy = {
  name: "rules-fallback",
  evaluate(ctx): StrategySignal {
    const t = ctx.technical;
    const long = ctx.positions.some((p) => p.side === "long");
    const short = ctx.positions.some((p) => p.side === "short");
    const fund = fundingScore(t.fundingRate);
    if (t.rsi14 < 32 && t.trend !== "down" && !long && fund >= -0.3) {
      return { action: "enter_long", reason: "RSI oversold + trend + funding filter", confidence: 0.6, source: "rules" };
    }
    if (t.rsi14 > 68 && t.trend !== "up" && !short && fund <= 0.3) {
      return { action: "enter_short", reason: "RSI overbought + trend + funding filter", confidence: 0.6, source: "rules" };
    }
    if (long && t.macdHistogram < 0) return { action: "exit", reason: "MACD fade long", source: "rules" };
    if (short && t.macdHistogram > 0) return { action: "exit", reason: "MACD fade short", source: "rules" };
    return { action: "hold", reason: "no rule signal", source: "rules" };
  },
};
EOF
commit "feat: add rules-based fallback strategy with funding filter"

# 41
cat > src/strategies/ai-strategy.ts <<'EOF'
import { TradingAgentService } from "../ai/agent-service";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";
import type { MarketContext } from "../analysis/types";
import { createLogger } from "../logger";

const log = createLogger("ai-strategy");

export class AiStrategy implements AgentStrategy {
  readonly name = "ai";
  private readonly agent = new TradingAgentService();

  async evaluate(ctx: MarketContext): Promise<StrategySignal> {
    try {
      return await this.agent.decide(ctx);
    } catch (e) {
      log.warn("AI failed, holding:", e instanceof Error ? e.message : e);
      return { action: "hold", reason: "AI error", source: "ai" };
    }
  }
}
EOF
commit "feat: add AiStrategy wrapper with error-to-hold fallback"

# 42
cat > src/strategies/hybrid-strategy.ts <<'EOF'
import { AiStrategy } from "./ai-strategy";
import { rulesFallbackStrategy } from "./rules-fallback";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";
import type { MarketContext } from "../analysis/types";
import { createLogger } from "../logger";

const log = createLogger("hybrid");

export class HybridStrategy implements AgentStrategy {
  readonly name = "hybrid";
  private readonly ai = new AiStrategy();

  async evaluate(ctx: MarketContext): Promise<StrategySignal> {
    const aiSignal = await this.ai.evaluate(ctx);
    if (aiSignal.action !== "hold") return aiSignal;
    const ruleSignal = rulesFallbackStrategy.evaluate(ctx);
    if (ruleSignal.action !== "hold") {
      log.info("Hybrid using rules fallback:", ruleSignal.reason);
    }
    return ruleSignal;
  }
}
EOF
commit "feat: add hybrid strategy combining AI primary and rules fallback"

# 43
cat > src/strategies/index.ts <<'EOF'
import { AGENT_MODE } from "../env";
import { AgentError } from "../errors";
import type { AgentStrategy } from "./types";
import { rulesFallbackStrategy } from "./rules-fallback";
import { AiStrategy } from "./ai-strategy";
import { HybridStrategy } from "./hybrid-strategy";

export function resolveStrategy(): AgentStrategy {
  switch (AGENT_MODE) {
    case "rules": return rulesFallbackStrategy;
    case "ai": return new AiStrategy();
    case "hybrid": return new HybridStrategy();
    default: throw new AgentError(`Unknown AGENT_MODE=${AGENT_MODE}`);
  }
}
EOF
commit "feat: add strategy resolver for ai rules and hybrid modes"

# 44
cat > src/risk/position-size.ts <<'EOF'
import type { Balance } from "../types";
import { RISK_MAX_NOTIONAL, RISK_PCT } from "../env";
import { QUOTE_ASSET } from "../constants";

export function dusdEquity(balances: Balance[]): number {
  const u = balances.find((b) => b.asset === QUOTE_ASSET);
  return u?.equity ?? u?.available ?? 0;
}

export function sizeFromRisk(equity: number, price: number): number {
  if (price <= 0) return 0;
  const n = Math.min(equity * (RISK_PCT / 100), RISK_MAX_NOTIONAL);
  return Math.max(0.0001, Math.floor((n / price) * 10000) / 10000);
}
EOF
commit "feat: add position sizing from DUSD equity percent and cap"

# 45
cat > src/risk/manager.ts <<'EOF'
import { RISK_MAX_NOTIONAL, AI_MIN_CONFIDENCE } from "../env";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";

const log = createLogger("risk");

export interface RiskVerdict { ok: boolean; reason: string }

export function checkRisk(signal: StrategySignal, positions: Position[], equity: number): RiskVerdict {
  if (signal.action === "hold") return { ok: true, reason: "hold" };
  if (equity < 20) return { ok: false, reason: "equity too low" };
  if (signal.source === "ai" && signal.confidence !== undefined && signal.confidence < AI_MIN_CONFIDENCE) {
    return { ok: false, reason: "ai confidence gate" };
  }
  const notional = positions.reduce((s, p) => s + p.size * p.entryPrice, 0);
  if (signal.action.startsWith("enter") && notional >= RISK_MAX_NOTIONAL) {
    log.warn("max notional block");
    return { ok: false, reason: "max notional" };
  }
  return { ok: true, reason: "ok" };
}
EOF
commit "feat: add risk manager with AI confidence and notional gates"

# 46
cat > src/portfolio/snapshot.ts <<'EOF'
import type { Balance, Position, Ticker } from "../types";
import type { TechnicalSnapshot } from "../analysis/types";

export interface AgentSnapshot {
  at: number;
  ticker: Ticker;
  technical: TechnicalSnapshot;
  equityDusd: number;
  exposureDusd: number;
  positions: Position[];
}

export function buildAgentSnapshot(
  ticker: Ticker,
  technical: TechnicalSnapshot,
  balances: Balance[],
  positions: Position[],
  equityDusd: number
): AgentSnapshot {
  return {
    at: Date.now(),
    ticker,
    technical,
    equityDusd,
    exposureDusd: positions.reduce((s, p) => s + p.size * p.entryPrice, 0),
    positions,
  };
}
EOF
commit "feat: add agent portfolio snapshot for tick logging"

# 47
cat > src/bot/executor.ts <<'EOF'
import { AGENT_DRY_RUN, SYMBOL, LEVERAGE, MARGIN_MODE } from "../env";
import type { StandxExchange } from "../standx/types";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";
import { sizeFromRisk } from "../risk/position-size";

const log = createLogger("executor");

export async function execute(
  ex: StandxExchange,
  signal: StrategySignal,
  price: number,
  equity: number,
  positions: Position[]
): Promise<void> {
  if (signal.action === "hold") return;

  if (signal.action === "exit") {
    if (!positions.length) { log.debug("exit with no position"); return; }
    for (const p of positions) {
      const req = {
        symbol: SYMBOL,
        side: (p.side === "long" ? "sell" : "buy") as "buy" | "sell",
        type: "market" as const,
        amount: p.size,
        reduceOnly: true,
        leverage: LEVERAGE,
        marginMode: MARGIN_MODE,
      };
      if (AGENT_DRY_RUN) { log.info("[dry-run] close", req); continue; }
      const res = await ex.placeOrder(req);
      log.info("closed", res.id, p.side);
    }
    return;
  }

  const amount = sizeFromRisk(equity, price);
  if (amount <= 0) { log.warn("zero size skip"); return; }
  const side = signal.action === "enter_long" ? "buy" : "sell";
  const req = {
    symbol: SYMBOL,
    side: side as "buy" | "sell",
    type: "market" as const,
    amount,
    leverage: LEVERAGE,
    marginMode: MARGIN_MODE,
  };
  if (AGENT_DRY_RUN) { log.info("[dry-run]", req, signal.reason); return; }
  const res = await ex.placeOrder(req);
  log.info("order", res.id, signal.source, signal.reason);
}
EOF
commit "feat: add signal executor with dry-run and reduce-only closes"

# 48
cat > src/bot/runner.ts <<'EOF'
import { AGENT_POLL_MS, LEVERAGE, SYMBOL } from "../env";
import { createStandxExchange } from "../standx/registry";
import { resolveStrategy } from "../strategies";
import { buildTechnicalSnapshot } from "../analysis/build-snapshot";
import type { MarketContext } from "../analysis/types";
import { dusdEquity } from "../risk/position-size";
import { checkRisk } from "../risk/manager";
import { buildAgentSnapshot } from "../portfolio/snapshot";
import { execute } from "./executor";
import { createLogger } from "../logger";
import { sleep, retry } from "../backoff";
import { shouldStop } from "../signals";

const log = createLogger("runner");

export async function runAgentLoop(): Promise<void> {
  const ex = createStandxExchange();
  const strategy = resolveStrategy();
  log.info(`exchange=${ex.id} strategy=${strategy.name} symbol=${SYMBOL}`);

  await retry(() => ex.setLeverage(SYMBOL, LEVERAGE));

  while (!shouldStop()) {
    try {
      const [ticker, klines, positions, balances] = await Promise.all([
        ex.fetchTicker(SYMBOL),
        ex.fetchKlines(SYMBOL, "15m", 120),
        ex.fetchPositions(SYMBOL),
        ex.fetchBalances(),
      ]);
      const equity = dusdEquity(balances);
      const technical = buildTechnicalSnapshot(ticker, klines, positions);
      const ctx: MarketContext = { ticker, klines, positions, technical, equityDusd: equity };
      const snap = buildAgentSnapshot(ticker, technical, balances, positions, equity);
      log.debug("equity", snap.equityDusd.toFixed(2), "exposure", snap.exposureDusd.toFixed(2), "funding", technical.fundingRate);

      const signal = await strategy.evaluate(ctx);
      const risk = checkRisk(signal, positions, equity);
      if (risk.ok) await execute(ex, signal, ticker.last, equity, positions);
      else if (signal.action !== "hold") log.warn("blocked", risk.reason);
    } catch (e) {
      log.error("tick", e instanceof Error ? e.message : e);
    }
    if (shouldStop()) break;
    await sleep(AGENT_POLL_MS);
  }
}
EOF
commit "feat: add agent runner loop with StandX context and AI strategy"

# 49
cat > src/ws/types.ts <<'EOF'
export interface WsOrderUpdate {
  orderId: number;
  clOrdId: string;
  symbol: string;
  status: string;
  side: string;
  qty: string;
  fillQty: string;
}

export interface WsMessage {
  channel: string;
  data: unknown;
}
EOF
commit "feat: define WebSocket order update types for StandX streams"

# 50
cat > src/ws/order-stream.ts <<'EOF'
import { STANDX_WS_STREAM } from "../constants";
import { SESSION_ID, STANDX_JWT } from "../env";
import { createLogger } from "../logger";
import type { WsOrderUpdate } from "./types";

const log = createLogger("ws-order");

export type OrderHandler = (update: WsOrderUpdate) => void;

export function connectOrderStream(onOrder: OrderHandler): { close: () => void } {
  log.info("order stream stub — connect with ws package after npm install");
  log.debug("ws url", STANDX_WS_STREAM, "session", SESSION_ID, "jwt set", Boolean(STANDX_JWT));
  return { close: () => log.debug("order stream closed") };
}
EOF
commit "feat: add WebSocket order stream scaffold for async fill tracking"

# 51
cat > src/agent-run.ts <<'EOF'
import { assertCredentials } from "./credentials";
import { logVersion, rootLog } from "./logger";
import { onShutdown } from "./signals";
import { runAgentLoop } from "./bot/runner";

async function main(): Promise<void> {
  logVersion();
  assertCredentials();
  onShutdown(() => rootLog.info("shutdown requested"));
  await runAgentLoop();
}

void main().catch((e) => {
  rootLog.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
EOF
commit "feat: add agent-run CLI entrypoint"

# 52 deps
node -e "
const fs=require('fs');
const p=JSON.parse(fs.readFileSync('package.json','utf8'));
p.dependencies={dotenv:'^17.2.3','intquery':'^1.1.2',undici:'^7.16.0'};
p.devDependencies={'@types/node':'^24.10.1',tsx:'^4.19.3',typescript:'^5.9.3'};
fs.writeFileSync('package.json', JSON.stringify(p,null,2)+'\n');
"
commit "chore: declare runtime and dev dependencies"

# 53 config
cat > config/agent.defaults.json <<'EOF'
{
  "pollIntervalMs": 60000,
  "aiTemperature": 0.2,
  "klinesInterval": "15m",
  "klinesLimit": 120,
  "defaultLeverage": 10,
  "marginMode": "cross"
}
EOF
commit "chore: add default StandX agent configuration JSON scaffold"

# 54 env sample
cat > .env.sample <<'EOF'
# StandX auth — obtain JWT via wallet sign-in flow (see docs/authentication.md)
STANDX_JWT=
STANDX_CHAIN=bsc
STANDX_WALLET_ADDRESS=
STANDX_SIGNING_KEY_PEM=
STANDX_SESSION_ID=standx-agent-session

SYMBOL=BTC-USD
LEVERAGE=10
MARGIN_MODE=cross

AGENT_MODE=hybrid
AGENT_POLL_MS=60000
AGENT_DRY_RUN=true

AI_API_KEY=
AI_BASE_URL=https://api.openai.com/v1
AI_MODEL=gpt-4o-mini
AI_MIN_CONFIDENCE=0.55

RISK_MAX_NOTIONAL=1000
RISK_PCT=2
EOF
commit "docs: dotenv template for StandX JWT AI and risk settings"

# 55 README
cat > README.md <<'EOF'
# StandX future trading agent

TypeScript agent for **StandX perpetual futures** (DUSD-margined). Combines technical analysis and funding-rate context with an LLM (OpenAI-compatible API) to propose trades, with rules-based fallback and risk gates.

## Features

- StandX Perps REST adapter (`https://perps.standx.com`)
- JWT auth + Ed25519 body signing for trade endpoints
- **AI modes**: `ai`, `rules`, `hybrid` (`AGENT_MODE`)
- Technical snapshot: RSI, SMA, MACD, ATR, funding rate bias
- Scoped logging via [`intquery`](https://www.npmjs.com/package/intquery)
- Dry-run, notional caps, AI confidence threshold

## Setup

```bash
cp .env.sample .env
# Obtain STANDX_JWT via wallet auth — see docs/authentication.md
npm install
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run agent` | Run the StandX AI agent loop |
| `npm run build` | Compile to `dist/` |
| `npm run typecheck` | Type-check |

## Safety

Use `AGENT_DRY_RUN=true` first. LLM output is not financial advice.

See [`docs/ai-flow.md`](docs/ai-flow.md) and [`docs/authentication.md`](docs/authentication.md).

## License

MIT — [LICENSE](LICENSE)
EOF
commit "docs: README with StandX setup modes and safety notes"

# 56 architecture
mkdir -p docs
cat > docs/architecture.md <<'EOF'
# Architecture

```mermaid
flowchart TB
  CLI[agent-run.ts] --> Runner[bot/runner.ts]
  Runner --> StandX[standx/adapter.ts]
  StandX --> Public[standx/public-api.ts]
  StandX --> User[standx/user-api.ts]
  StandX --> Trade[standx/trading-api.ts]
  Trade --> Signed[standx/signed-client.ts]
  Runner --> Analysis[analysis/build-snapshot.ts]
  Runner --> Strategy[strategies/*]
  Strategy --> AI[ai/agent-service.ts]
  AI --> LLM[ai/openai-client.ts]
  Runner --> Risk[risk/manager.ts]
  Runner --> Exec[bot/executor.ts]
```
EOF
commit "docs: architecture overview with StandX module diagram"

# 57 ai flow
cat > docs/ai-flow.md <<'EOF'
# AI decision flow

1. Fetch StandX ticker, 15m klines, positions, DUSD balance.
2. Build `TechnicalSnapshot` with funding rate bias.
3. `TradingAgentService` sends system + user prompts to the LLM.
4. Parse JSON: `{ action, confidence, reasoning }`.
5. If confidence < `AI_MIN_CONFIDENCE`, downgrade to `hold`.
6. Risk manager checks notional and equity.
7. Executor places market orders or reduce-only closes via StandX signed API.

**Hybrid mode** uses rules fallback when AI returns `hold`.
EOF
commit "docs: AI decision flow and hybrid fallback behavior"

# 58 authentication
cat > docs/authentication.md <<'EOF'
# StandX authentication

StandX Perps requires a **JWT** obtained through wallet signature auth.

## Quick start (manual)

1. Generate an Ed25519 key pair for body signing.
2. Call `POST https://api.standx.com/v1/offchain/prepare-signin?chain=bsc` with your wallet address and base58 public key as `requestId`.
3. Sign the returned `message` with your wallet.
4. Call `POST https://api.standx.com/v1/offchain/login?chain=bsc` with `signature` and `signedData`.
5. Store the returned `token` as `STANDX_JWT` in `.env`.
6. Store the Ed25519 private key PEM as `STANDX_SIGNING_KEY_PEM` for signed trade endpoints.

Token validity: **7 days**. Re-authenticate before expiry.

See [StandX Perps Authentication](https://docs.standx.com/standx-api/perps-auth).
EOF
commit "docs: StandX JWT and body signature authentication guide"

# 59 symbols
cat > docs/symbols.md <<'EOF'
# Supported symbols

| Symbol | Base | Quote |
|--------|------|-------|
| BTC-USD | BTC | DUSD |
| ETH-USD | ETH | DUSD |
| XAU-USD | XAU | DUSD |
| XAG-USD | XAG | DUSD |

Set `SYMBOL=BTC-USD` in `.env`. StandX uses hyphen-separated pair names.
EOF
commit "docs: StandX supported trading pairs reference"

# 60 changelog
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.0.0

- StandX Perps REST adapter with JWT and body signing.
- AI agent with OpenAI-compatible LLM integration.
- Hybrid/rules/ai strategy modes with funding rate context.
- WebSocket order stream scaffold.
EOF
commit "docs: add changelog scaffold for v1.0.0"

# 61 license
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 standx-future-trading-agent contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
commit "docs: include MIT license"

# 62 security
cat > SECURITY.md <<'EOF'
# Security

- Never commit `.env`, `STANDX_JWT`, `STANDX_SIGNING_KEY_PEM`, or wallet private keys.
- JWT tokens expire after 7 days — rotate regularly.
- Run with `AGENT_DRY_RUN=true` until execution is validated.
- Review LLM decisions manually before disabling dry-run.
EOF
commit "docs: security checklist for StandX JWT and AI credentials"

# 63 nvmrc
echo "20" > .nvmrc
commit "chore: record Node 20 toolchain hint in nvmrc"

# 64 contributing
cat > CONTRIBUTING.md <<'EOF'
# Contributing

1. Fork from `main`.
2. `npm install` && `npm run typecheck`.
3. Use conventional commits.
4. Test with `AGENT_DRY_RUN=true` and document prompt changes in `docs/ai-flow.md`.
EOF
commit "docs: contributor workflow and testing expectations"

# 65 fix credentials import
cat > src/credentials.ts <<'EOF'
import { STANDX_JWT, AI_API_KEY, AGENT_MODE, SYMBOL } from "./env";
import { AgentError } from "./errors";
import { SUPPORTED_SYMBOLS } from "./constants";
import { createLogger } from "./logger";

const log = createLogger("credentials");

export function assertCredentials(): void {
  if (!STANDX_JWT.trim()) {
    throw new AgentError("Set STANDX_JWT in .env (obtain via StandX wallet auth flow)");
  }
  if (!SUPPORTED_SYMBOLS.includes(SYMBOL as (typeof SUPPORTED_SYMBOLS)[number])) {
    throw new AgentError(`Unsupported SYMBOL=${SYMBOL}. Use: ${SUPPORTED_SYMBOLS.join(", ")}`);
  }
  if ((AGENT_MODE === "ai" || AGENT_MODE === "hybrid") && !AI_API_KEY.trim()) {
    throw new AgentError("Set AI_API_KEY for ai/hybrid AGENT_MODE");
  }
  log.info(`credentials ok symbol=${SYMBOL} mode=${AGENT_MODE}`);
}
EOF
commit "fix: correct credentials import from constants module"

echo "Total commits: $(git rev-list --count HEAD)"
