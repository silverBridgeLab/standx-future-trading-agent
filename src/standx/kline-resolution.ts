const INTERVAL_TO_RESOLUTION: Record<string, string> = {
  "1m": "1",
  "5m": "5",
  "15m": "15",
  "1h": "60",
  "60m": "60",
  "1d": "1D",
  "1D": "1D",
  "1w": "1W",
  "1W": "1W",
  "1M": "1M",
};

const RESOLUTION_SECONDS: Record<string, number> = {
  "1": 60,
  "5": 300,
  "15": 900,
  "60": 3600,
  "1D": 86400,
  "1W": 604800,
  "1M": 2592000,
};

export function toKlineResolution(interval: string): string {
  return INTERVAL_TO_RESOLUTION[interval] ?? interval;
}

export function klineBarSeconds(resolution: string): number {
  return RESOLUTION_SECONDS[resolution] ?? 900;
}
