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
