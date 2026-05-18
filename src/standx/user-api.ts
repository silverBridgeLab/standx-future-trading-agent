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
