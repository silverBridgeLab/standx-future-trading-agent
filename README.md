# StandX future trading agent

TypeScript agent for **StandX perpetual futures** (DUSD-margined). Combines technical analysis and funding-rate context with an LLM (OpenAI-compatible API) to propose trades, with rules-based fallback and risk gates.

## Features

- StandX Perps REST adapter (`https://perps.standx.com`)
- JWT auth + Ed25519 body signing for trade endpoints
- **AI modes**: `ai`, `rules`, `hybrid` (`AGENT_MODE`)
- Technical snapshot: RSI, SMA, MACD, ATR, funding rate bias
- Scoped logging via [`ts-logger-pack`](https://www.npmjs.com/package/ts-logger-pack)
- Dry-run, notional caps, AI confidence threshold

## Setup

```bash
cp .env.sample .env
# Obtain STANDX_JWT via wallet auth — see docs/authentication.md
npm install
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run agent` | Run the StandX AI agent loop |
| `npm run build` | Compile to `dist/` |
| `npm run typecheck` | Type-check |

## Safety

Use `AGENT_DRY_RUN=true` first. LLM output is not financial advice.

See [`docs/ai-flow.md`](docs/ai-flow.md) and [`docs/authentication.md`](docs/authentication.md).

## License

MIT — [LICENSE](LICENSE)
