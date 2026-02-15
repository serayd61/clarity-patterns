# Price Oracle Pattern

A decentralized price feed pattern for DeFi applications on Stacks.

## Overview

The Price Oracle pattern provides a secure and reliable way to get asset prices on-chain. It supports multiple price sources, weighted averages, and staleness checks.

## Features

- **Multi-source Support**: Accept prices from multiple authorized sources
- **Weighted Averages**: Calculate prices using configurable weights
- **Staleness Protection**: Reject stale prices automatically
- **Admin Controls**: Manage authorized sources and parameters
- **Price Conversion**: Helper functions for cross-asset conversions

## Usage

### Setting Up

```clarity
;; Add authorized price source
(contract-call? .price-oracle add-authorized-source 'SP123...)

;; Set minimum required sources
(contract-call? .price-oracle set-min-sources u3)
```

### Submitting Prices

```clarity
;; Submit price with weight
(contract-call? .price-oracle submit-price "STX" u1850000 u50)
;; Price: $1.85 (6 decimals), Weight: 50%
```

### Reading Prices

```clarity
;; Get current price
(contract-call? .price-oracle get-price "STX")
;; Returns: (ok u1850000)

;; Check if price is fresh
(contract-call? .price-oracle is-price-fresh "STX")
;; Returns: true/false

;; Convert between assets
(contract-call? .price-oracle convert-amount "STX" "USDA" u1000000)
```

## Security Considerations

1. **Source Authorization**: Only whitelisted sources can submit prices
2. **Staleness Threshold**: Prices older than ~2 hours are rejected
3. **Weight Validation**: Weights must be between 1-100
4. **Owner Controls**: Critical functions restricted to contract owner

## Integration Example

```clarity
;; In your DeFi contract
(define-private (get-collateral-value (amount uint))
  (let
    (
      (price (unwrap! (contract-call? .price-oracle get-price "STX") (err u500)))
    )
    (ok (/ (* amount price) u1000000))
  )
)
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| STALENESS_THRESHOLD | 120 blocks | ~2 hours |
| ERR_NOT_AUTHORIZED | u100 | Unauthorized caller |
| ERR_INVALID_PRICE | u101 | Invalid price value |
| ERR_STALE_PRICE | u102 | Price too old |
| ERR_SOURCE_NOT_FOUND | u103 | Asset not found |

## Best Practices

1. Use multiple price sources for critical applications
2. Set appropriate staleness thresholds for your use case
3. Monitor source activity and disable inactive sources
4. Consider using time-weighted average prices (TWAP) for large trades
