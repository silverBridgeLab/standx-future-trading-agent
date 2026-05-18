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
