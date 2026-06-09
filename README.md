# sarek-contracts

Smart contracts for the [Sarek](https://www.sarek.technology/) platform. A data integrity and
verification system built on zkSync Era.

## Contracts

**HashStamp.sol** — Stores MMR roots on-chain as immutable timestamps.
Permissionless — anyone can stamp and verify.

**MMRVerifier.sol** — Verifies MMR leaf inclusion
on-chain. Pure mathematics, no state, no storage writes. Free to call.

## Architecture

Sarek builds a Merkle Mountain Range (MMR) from hashed data. Each batch
of hashes produces an MMR root that is stamped on-chain via HashStamp.
MMRVerifier enables permissionless leaf verification directly against the
stamped root, no server required.

Hash function: keccak256 which matches backend for
consistent on-chain verification.

## Deployments

| Contract    | Network            | Address                                      |
| ----------- | ------------------ | -------------------------------------------- |
| HashStamp   | zkSync Era Sepolia | `0xF7D64564b639B05496b047a2057a3E60cD7dEeD3` |
| MMRVerifier | zkSync Era Sepolia | `0x281bF8d48f4Dccb6Fc5A8527a7928534eAA20085` |

## Getting started

Install dependencies and run tests:

```bash
forge soldeer install
forge test
```

## Part of

These contracts are part of [Sarek](https://www.sarek.technology/)
— an AI accountability and data integrity platform.
