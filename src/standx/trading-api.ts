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

interface OpenOrdersPage {
  result: { id: number }[];
}

export async function cancelOpenOrders(symbol: string): Promise<void> {
  const open = await standxRequest<OpenOrdersPage>({
    method: "GET",
    path: `/api/query_open_orders?symbol=${encodeURIComponent(symbol)}`,
  });
  const list = open.result ?? [];
  if (!list.length) return;
  await standxRequest({
    method: "POST",
    path: "/api/cancel_orders",
    body: { order_id_list: list.map((o) => o.id) },
    signed: true,
    session: true,
  });
}
