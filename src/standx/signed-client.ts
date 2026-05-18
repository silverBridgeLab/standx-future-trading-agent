import { STANDX_PERPS_BASE } from "../constants";
import { httpJson } from "../http/client";
import { getJwt } from "./auth/jwt-store";
import { encodeBodySignature } from "./auth/body-signature";
import { SESSION_ID } from "../env";
import { AgentError } from "../errors";
import type { StandxApiResponse } from "./types";

export interface SignedRequestOpts {
  method: "GET" | "POST";
  path: string;
  body?: Record<string, unknown>;
  signed?: boolean;
  session?: boolean;
}

function authHeaders(): Record<string, string> {
  return { Authorization: `Bearer ${getJwt()}`, "Content-Type": "application/json" };
}

export async function standxRequest<T>(opts: SignedRequestOpts): Promise<T> {
  const url = `${STANDX_PERPS_BASE}${opts.path}`;
  const bodyStr = opts.body ? JSON.stringify(opts.body) : undefined;
  const headers: Record<string, string> = { ...authHeaders() };
  if (opts.session) headers["x-session-id"] = SESSION_ID;
  if (opts.signed && bodyStr) {
    const keyPem = process.env.STANDX_SIGNING_KEY_PEM ?? "";
    if (!keyPem.trim()) throw new AgentError("STANDX_SIGNING_KEY_PEM required for signed endpoints");
    Object.assign(headers, encodeBodySignature(bodyStr, keyPem));
  }
  const raw = await httpJson<StandxApiResponse<T> | T>(url, {
    method: opts.method,
    headers,
    body: bodyStr,
  });
  if (typeof raw === "object" && raw !== null && "code" in raw) {
    const wrapped = raw as StandxApiResponse<T>;
    if (wrapped.code !== 0) {
      throw new AgentError(wrapped.message ?? "StandX API error", { code: String(wrapped.code) });
    }
    return (wrapped.result ?? wrapped) as T;
  }
  return raw as T;
}
