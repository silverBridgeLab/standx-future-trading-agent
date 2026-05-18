import { AGENT_POLL_MS, LEVERAGE, SYMBOL } from "../env";
import { createStandxExchange } from "../standx/registry";
import { resolveStrategy } from "../strategies";
import { buildTechnicalSnapshot } from "../analysis/build-snapshot";
import type { MarketContext } from "../analysis/types";
import { dusdEquity } from "../risk/position-size";
import { checkRisk } from "../risk/manager";
import { buildAgentSnapshot } from "../portfolio/snapshot";
import { execute } from "./executor";
import { createLogger } from "../logger";
import { sleep, retry } from "../backoff";
import { shouldStop } from "../signals";

const log = createLogger("runner");

export async function runAgentLoop(): Promise<void> {
  const ex = createStandxExchange();
  const strategy = resolveStrategy();
  log.info(`exchange=${ex.id} strategy=${strategy.name} symbol=${SYMBOL}`);

  await retry(() => ex.setLeverage(SYMBOL, LEVERAGE));

  while (!shouldStop()) {
    try {
      const [ticker, klines, positions, balances] = await Promise.all([
        ex.fetchTicker(SYMBOL),
        ex.fetchKlines(SYMBOL, "15m", 120),
        ex.fetchPositions(SYMBOL),
        ex.fetchBalances(),
      ]);
      const equity = dusdEquity(balances);
      const technical = buildTechnicalSnapshot(ticker, klines, positions);
      const ctx: MarketContext = { ticker, klines, positions, technical, equityDusd: equity };
      const snap = buildAgentSnapshot(ticker, technical, balances, positions, equity);
      log.debug("equity", snap.equityDusd.toFixed(2), "exposure", snap.exposureDusd.toFixed(2), "funding", technical.fundingRate);

      const signal = await strategy.evaluate(ctx);
      const risk = checkRisk(signal, positions, equity);
      if (risk.ok) await execute(ex, signal, ticker.last, equity, positions);
      else if (signal.action !== "hold") log.warn("blocked", risk.reason);
    } catch (e) {
      log.error("tick", e instanceof Error ? e.message : e);
    }
    if (shouldStop()) break;
    await sleep(AGENT_POLL_MS);
  }
}
