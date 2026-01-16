# Development Guide

This guide helps developers build and test the Soroban raffle contract locally.

## Project Layout

-   `contracts/hello-world/src/lib.rs`: Soroban raffle contract
-   `contracts/hello-world/src/test.rs`: Contract tests
-   `README.md`: Project overview

## Prerequisites

-   Rust toolchain (stable)
-   Cargo (bundled with Rust)
-   Stellar CLI (optional, for deployment)

## Build

```bash
cargo build -p hello-world
```

## Test

```bash
cargo test -p hello-world
```

## Notes

-   The contract uses Soroban SDK v23 from the workspace.
-   Network access is required the first time dependencies are fetched.

