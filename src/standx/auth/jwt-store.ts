import { STANDX_JWT } from "../../env";
import { AgentError } from "../../errors";

let cached = STANDX_JWT;

export function getJwt(): string {
  if (!cached.trim()) throw new AgentError("STANDX_JWT not configured");
  return cached;
}

export function setJwt(token: string): void {
  cached = token;
}
