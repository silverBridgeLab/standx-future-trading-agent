export interface WsOrderUpdate {
  orderId: number;
  clOrdId: string;
  symbol: string;
  status: string;
  side: string;
  qty: string;
  fillQty: string;
}

export interface WsMessage {
  channel: string;
  data: unknown;
}
