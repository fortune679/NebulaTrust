# NebulaTrust

A decentralized Bitcoin-backed lending platform built on Stacks.

## Overview

NebulaTrust enables users to create trustless lending agreements using Bitcoin as security. The platform allows borrowers to lock their Bitcoin as security and receive credit, while maintaining a minimum security-to-credit ratio to ensure loan stability.

## Key Features

- **Bitcoin-Backed Credit**: Use your Bitcoin holdings as security to access credit
- **Customizable Terms**: Set your own yield rates and trust durations
- **Security Management**: Add or withdraw security as needed while maintaining required ratios
- **Trustless Settlements**: Automated trust settlement process with built-in yield calculations
- **Foreclosure Protection**: Clear terms for trust foreclosure in case of default

## Smart Contract Functions

### Core Functions

- `create-trust`: Establish a new credit agreement by providing security
- `add-security`: Increase the security amount for an existing trust
- `withdraw-security`: Reduce security amount while maintaining minimum requirements
- `settle-trust`: Repay the credit amount plus yield to close the trust
- `foreclose-trust`: Process a defaulted trust after the duration has expired

### Read-Only Functions

- `get-trust-details`: View complete details of a trust agreement
- `get-trust-settlement-status`: Check payment status of a trust

## Security Measures

- Minimum security ratio of 150% to protect against market volatility
- Overflow protection for all numeric operations
- Clear error handling with specific error codes
- Parameter validation for all user inputs

## Error Codes

- `ERR-INSUFFICIENT-FUNDS (u100)`: Not enough funds for the requested operation
- `ERR-UNAUTHORIZED (u101)`: User not authorized to perform this action
- `ERR-TRUST-NOT-FOUND (u102)`: The specified trust does not exist
- `ERR-TRUST-ALREADY-EXISTS (u103)`: A trust with this ID already exists
- `ERR-TRUST-REPAYMENT-FAILED (u104)`: Trust settlement operation failed
- `ERR-FORECLOSURE-NOT-ALLOWED (u105)`: Trust cannot be foreclosed yet
- `ERR-INVALID-PARAMETER (u106)`: One or more parameters are invalid
- `ERR-INSUFFICIENT-SECURITY (u107)`: Security amount is below the required minimum

## Getting Started

To interact with NebulaTrust:

1. Connect your Stacks wallet
2. Navigate to the "Create Trust" section
3. Enter your desired credit amount, yield rate, and duration
4. Deposit the required security (minimum 150% of credit amount)
5. Confirm and create your trust

## Development

This project is built using Clarity, the smart contract language for the Stacks blockchain.

To set up a local development environment:

```bash
# Install Clarinet
curl -sS https://deno.land/x/clarinet/install.sh | sh

# Clone repository
git clone https://github.com/yourusername/nebulatrust.git
cd nebulatrust

# Run tests
clarinet test
```
