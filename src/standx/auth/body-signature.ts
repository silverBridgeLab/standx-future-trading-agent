import { sign } from "node:crypto";
import { randomUUID } from "node:crypto";

export interface BodySignatureHeaders {
  "x-request-sign-version": string;
  "x-request-id": string;
  "x-request-timestamp": string;
  "x-request-signature": string;
}

export function encodeBodySignature(
  payload: string,
  signingKeyPem: string
): BodySignatureHeaders {
  const version = "v1";
  const id = randomUUID();
  const timestamp = String(Date.now());
  const message = `${version},${id},${timestamp},${payload}`;
  const signature = sign(null, Buffer.from(message, "utf8"), signingKeyPem).toString("base64");
  return {
    "x-request-sign-version": version,
    "x-request-id": id,
    "x-request-timestamp": timestamp,
    "x-request-signature": signature,
  };
}
