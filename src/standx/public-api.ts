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
