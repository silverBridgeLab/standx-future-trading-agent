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
