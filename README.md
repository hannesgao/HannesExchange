# HannesExchange

HannesExchange is a smart contract implementation of a decentralized exchange based on the constant product automated market maker model. It includes two versions: `HannesExchangeV1` and `HannesExchangeV2`:

- `HannesExchangeV1`: Uses `ETH` as the base currency, supporting only direct `ETH ↔ ERC20` swaps
- `HannesExchangeV2`: Supports any `ERC20` token pair, removing the `ETH` base currency restriction


## 1. Project Documentations

### 1.1 Case Document
- [English Version](docs/0_programming_challenge_case_en.md)
- [Chinese Version](docs/0_programming_challenge_case_cn.md)

### 1.2 Architectural Overview
- [English Version](docs/1_architectural_overview_en.md)
- [Chinese Version](docs/1_architectural_overview_cn.md)

### 1.3 Developer Guide
- [English Version](docs/2_developer_guide_en.md)
- [Chinese Version](docs/2_developer_guide_cn.md)

## 2. Key Features
- Advanced role-based access control
- Emergency circuit breaker mechanism
- Comprehensive reentrancy protection
- Gas-optimized operations
- UUPS upgradeable design pattern
- Complete test coverage

## 3. Technical Stack
- Solidity
- Foundry Framework
- OpenZeppelin Contracts
- Ethereum Sepolia Testnet

## 3. Prerequisites
- Solidity
- Rust and Cargo
- Foundry Toolchain
- Git

## 4. Installation and Setup

### 4.1 Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 4.2 Clone the repository
```bash
git clone https://github.com/hannesgao/HannesExchange.git
cd HannesExchange
```

### 4.3 Install dependencies
```bash
forge install
```

### 4.4 Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your configuration
```

## 5. Testing
```bash
forge test -vvvvv
```

## 6. Deployment
### 6.1 Deploy HannesExchangeV1 Factory Contract

```bash
forge script script/DeployHannesExchangeV1Factory.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

### 6.2 Deploy HannesExchangeV1 Liquidity Pool Contract

```bash
forge script script/DeployHannesExchangeV1Pair.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

### 6.3 Deploy HannesExchangeV2 Factory Contract

```bash
forge script script/DeployHannesExchangeV2.s.sol:DeployHannesExchangeV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

### 6.4 Deploy HannesExchangeV2 Liquidity Pool Contract

```bash
forge script script/DeployHannesExchangeV2.s.sol:CreatePairV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

## 7. Security Features
- Role-based access control
- Emergency pause functionality
- Reentrancy protection
- Safe transfer implementations
- Overflow/underflow protection
- DoS attack prevention
- Comprehensive security checks

## 8. License
MIT License

---