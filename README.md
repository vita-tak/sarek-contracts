# Sarek Smart Contracts

Smart contracts for the [Sarek](https://www.sarek.technology/) platform. A blockchain stamping and 
verification system built on zkSync Era.

## Contracts

**HashStamp.sol** — Stores MMR roots on-chain as immutable timestamps.
Permissionless i.e. anyone can stamp and verify.

**MMRVerifier.sol** — Verifies Merkle Mountain Range leaf inclusion 
on-chain. Pure mathematics. No state, no storage writes. Free to call.

## Architecture

Each batch of hashes produces an MMR root that is stamped on-chain via HashStamp. 
MMRVerifier enables permissionless leaf verification directly against the 
stamped root. No server required.

Hash function: keccak256 — matches EvmMMRService in the backend for 
consistent on-chain verification.

## Deployments

| Contract | Network | Address |
|---|---|---|
| HashStamp | zkSync Era Sepolia | `0x90AA8c842FF282baf93040e8E4a6dd8B3F995510` |
| MMRVerifier | zkSync Era Sepolia | `0x3AC3D57BD681d0da3D007857b60a7Bd505D6e2DA` |

## Getting started

Install dependencies and run tests:

```bash
forge soldeer install
forge test
```

## Part of

These contracts are part of [Sarek](https://www.sarek.technology/) data integrity platform.
