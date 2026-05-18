import { fundingScore } from "../indicators/funding-bias";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";

export const rulesFallbackStrategy: AgentStrategy = {
  name: "rules-fallback",
  evaluate(ctx): StrategySignal {
    const t = ctx.technical;
    const long = ctx.positions.some((p) => p.side === "long");
    const short = ctx.positions.some((p) => p.side === "short");
    const fund = fundingScore(t.fundingRate);
    if (t.rsi14 < 32 && t.trend !== "down" && !long && fund >= -0.3) {
      return { action: "enter_long", reason: "RSI oversold + trend + funding filter", confidence: 0.6, source: "rules" };
    }
    if (t.rsi14 > 68 && t.trend !== "up" && !short && fund <= 0.3) {
      return { action: "enter_short", reason: "RSI overbought + trend + funding filter", confidence: 0.6, source: "rules" };
    }
    if (long && t.macdHistogram < 0) return { action: "exit", reason: "MACD fade long", source: "rules" };
    if (short && t.macdHistogram > 0) return { action: "exit", reason: "MACD fade short", source: "rules" };
    return { action: "hold", reason: "no rule signal", source: "rules" };
  },
};
