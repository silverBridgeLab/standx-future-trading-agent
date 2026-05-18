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
