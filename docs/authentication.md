# StandX authentication

StandX Perps requires a **JWT** obtained through wallet signature auth.

## Quick start (manual)

1. Generate an Ed25519 key pair for body signing.
2. Call `POST https://api.standx.com/v1/offchain/prepare-signin?chain=bsc` with your wallet address and base58 public key as `requestId`.
3. Sign the returned `message` with your wallet.
4. Call `POST https://api.standx.com/v1/offchain/login?chain=bsc` with `signature` and `signedData`.
5. Store the returned `token` as `STANDX_JWT` in `.env`.
6. Store the Ed25519 private key PEM as `STANDX_SIGNING_KEY_PEM` for signed trade endpoints.

Token validity: **7 days**. Re-authenticate before expiry.

See [StandX Perps Authentication](https://docs.standx.com/standx-api/perps-auth).
