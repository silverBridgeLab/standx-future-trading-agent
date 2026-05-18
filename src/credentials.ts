import { STANDX_JWT, AI_API_KEY, AGENT_MODE, SYMBOL, SUPPORTED_SYMBOLS } from "./env";
import { AgentError } from "./errors";
import { SUPPORTED_SYMBOLS as CONST_SYMBOLS } from "./constants";
import { createLogger } from "./logger";

const log = createLogger("credentials");

export function assertCredentials(): void {
  if (!STANDX_JWT.trim()) {
    throw new AgentError("Set STANDX_JWT in .env (obtain via StandX wallet auth flow)");
  }
  if (!CONST_SYMBOLS.includes(SYMBOL as (typeof CONST_SYMBOLS)[number])) {
    throw new AgentError(`Unsupported SYMBOL=${SYMBOL}. Use: ${CONST_SYMBOLS.join(", ")}`);
  }
  if ((AGENT_MODE === "ai" || AGENT_MODE === "hybrid") && !AI_API_KEY.trim()) {
    throw new AgentError("Set AI_API_KEY for ai/hybrid AGENT_MODE");
  }
  log.info(`credentials ok symbol=${SYMBOL} mode=${AGENT_MODE}`);
}
