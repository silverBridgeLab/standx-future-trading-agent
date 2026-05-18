# Security

- Never commit `.env`, `STANDX_JWT`, `STANDX_SIGNING_KEY_PEM`, or wallet private keys.
- JWT tokens expire after 7 days — rotate regularly.
- Run with `AGENT_DRY_RUN=true` until execution is validated.
- Review LLM decisions manually before disabling dry-run.
