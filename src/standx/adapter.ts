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
