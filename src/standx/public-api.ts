import { STANDX_PERPS_BASE } from "../constants";
import { httpJson } from "../http/client";
import type { Kline, Ticker } from "../types";
import { klineBarSeconds, toKlineResolution } from "./kline-resolution";

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

interface KlineHistoryResponse {
  s: string;
  t: number[];
  o: number[];
  h: number[];
  l: number[];
  c: number[];
  v: number[];
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
  const resolution = toKlineResolution(interval);
  const to = Math.floor(Date.now() / 1000);
  const from = to - klineBarSeconds(resolution) * limit;
  const q = new URLSearchParams({
    symbol,
    from: String(from),
    to: String(to),
    resolution,
    countback: String(limit),
  });
  const d = await httpJson<KlineHistoryResponse>(`${STANDX_PERPS_BASE}/api/kline/history?${q}`);
  if (d.s !== "ok" || !d.t?.length) return [];
  return d.t.map((time, i) => ({
    time: time * 1000,
    open: d.o[i],
    high: d.h[i],
    low: d.l[i],
    close: d.c[i],
    volume: d.v[i],
  }));
}
