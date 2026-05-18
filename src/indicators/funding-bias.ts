export type FundingBias = "long_pays" | "short_pays" | "neutral";

export function fundingBias(rate: number, threshold = 0.00005): FundingBias {
  if (rate > threshold) return "long_pays";
  if (rate < -threshold) return "short_pays";
  return "neutral";
}

export function fundingScore(rate: number): number {
  return Math.max(-1, Math.min(1, -rate * 10000));
}
