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
