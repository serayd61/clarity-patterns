# Clarity Patterns

A collection of reusable Clarity smart contract patterns for Stacks blockchain development.

## Overview

This library provides battle-tested, audited smart contract patterns that you can use as building blocks for your Stacks applications.

## Patterns Included

### Access Control

- **Ownable**: Single owner with transfer capability
- **Roles**: Role-based access control
- **Multisig**: Multi-signature operations
- **Timelock**: Time-delayed execution

### Token Standards

- **SIP-010**: Fungible token implementation
- **SIP-009**: NFT implementation
- **Wrapped Token**: Token wrapping pattern
- **Mintable**: Controlled minting with caps

### DeFi Patterns

- **Vault**: Secure token storage
- **Staking**: Stake and earn rewards
- **Vesting**: Token vesting schedules
- **Escrow**: Trustless escrow
- **Price Oracle**: Decentralized price feeds (NEW)

### Governance

- **Voting**: On-chain voting
- **Proposals**: Proposal management
- **Treasury**: Community treasury

## Installation

```bash
git clone https://github.com/serayd61/clarity-patterns.git
cd clarity-patterns
```

## Usage

Copy the patterns you need into your project:

```bash
cp contracts/access/ownable.clar your-project/contracts/
```

Or import as a dependency in Clarinet.toml:

```toml
[contracts.ownable]
path = "clarity-patterns/contracts/access/ownable.clar"
```

## Pattern: Ownable

Basic ownership pattern with transfer capability.

```clarity
;; contracts/access/ownable.clar

(define-data-var owner principal tx-sender)

(define-read-only (get-owner)
  (var-get owner)
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u401))
    (var-set owner new-owner)
    (ok true)
  )
)

(define-read-only (is-owner (account principal))
  (is-eq account (var-get owner))
)
```

## Pattern: SIP-010 Token

Standard fungible token implementation.

```clarity
;; See contracts/tokens/sip010.clar for full implementation
```

## Testing

Run tests with Clarinet:

```bash
clarinet test
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for your pattern
4. Submit a pull request

## Security

All patterns are provided as-is. While we strive for security, please audit any code before using in production.

## License

MIT License - see [LICENSE](LICENSE)
