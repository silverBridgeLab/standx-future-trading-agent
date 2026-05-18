import { STANDX_WS_STREAM } from "../constants";
import { SESSION_ID, STANDX_JWT } from "../env";
import { createLogger } from "../logger";
import type { WsOrderUpdate } from "./types";

const log = createLogger("ws-order");

export type OrderHandler = (update: WsOrderUpdate) => void;

export function connectOrderStream(onOrder: OrderHandler): { close: () => void } {
  log.info("order stream stub — connect with ws package after npm install");
  log.debug("ws url", STANDX_WS_STREAM, "session", SESSION_ID, "jwt set", Boolean(STANDX_JWT));
  return { close: () => log.debug("order stream closed") };
}
