export function buildUserPrompt(marketBlock: string, symbol: string): string {
  return `Exchange: StandX Perps
Trading pair: ${symbol}

Market context:
${marketBlock}

Provide the next trade action JSON.`;
}
