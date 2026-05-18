import type { StandxExchange } from "./types";
import { StandxPerpsAdapter } from "./adapter";

let instance: StandxExchange | null = null;

export function createStandxExchange(): StandxExchange {
  if (!instance) instance = new StandxPerpsAdapter();
  return instance;
}
