# HannesExchange Developer Guide

## 1. Project Overview

HannesExchange is a smart contract implementation of a decentralized exchange based on the constant product automated market maker model. It includes two versions: `HannesExchangeV1` and `HannesExchangeV2`:

- `HannesExchangeV1`: Uses `ETH` as the base currency, supporting only direct `ETH ↔ ERC20` swaps
- `HannesExchangeV2`: Supports any `ERC20` token pair, removing the `ETH` base currency restriction


## 2. Technology Stack

### 2.1 Smart Contract Development Language: Solidity

This project uses Solidity version: `^0.8.28`, with solc compiler version: `0.8.28+commit.7893614a.Emscripten.clang`

### 2.2 Smart Contract Development Framework: Foundry

This project employs Foundry as the smart contract development and testing framework. Foundry was chosen over Hardhat primarily for its faster execution speed and ability to write test cases and deployment scripts directly in Solidity, enhancing testing and deployment efficiency.

### 2.3 Test Network: Ethereum Sepolia

The project uses Ethereum Sepolia as the test network for deployment and smart contract testing.

#### 2.3.1 Test Network Configuration

The Sepolia test network RPC address can be configured in the Foundry project configuration file foundry.toml:

```TOML
[rpc_endpoints]
sepolia = "https://ethereum-sepolia-rpc.publicnode.com"
```

### 2.4 Smart Contract Standards

#### 2.4.1 ERC-20 Fungible Token

The project's main applications of the ERC-20 standard include:

- LP token implementation

```solidity
contract HannesExchangeV1Pair is ERC20Upgradeable {
    function initialize() {
        __ERC20_init("HannesExchange LP Token", "HELP");
    }
}
```

- Interaction with external ERC-20 tokens

```solidity
/// Using IERC20 interface to interact with external tokens
IERC20 public token0;
IERC20 public token1;

/// Safe ERC20 token transfer
IERC20(tokenAddress).safeTransferFrom(
    msg.sender,
    address(this),
    tokensAdded
);
```

#### 2.4.2 EIP-1967 Transparent Proxy

The project implements contract upgradeability using the EIP-1967 standard.

```solidity
/// Deploying new trading pairs in factory contract
ERC1967Proxy proxy = new ERC1967Proxy(
    address(exchangeImpl),
    initData
);
```

#### 2.4.3 ERC-1822 Universal Upgradeable Proxy

The project adopts the UUPS (Universal Upgradeable Proxy Standard) proxy pattern: upgrade logic resides in the implementation contract, using role-based access control to manage upgrade permissions, supporting seamless contract logic upgrades.

```solidity
contract HannesExchangeV1Factory is UUPSUpgradeable {
    function _authorizeUpgrade(address implementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
```

### 2.5 External Standard Contract Libraries

#### 2.5.1 OpenZeppelin Contracts

The project utilizes multiple OpenZeppelin standard contracts, including:

- Token contract library: For secure ERC20 token operations, handling compatibility issues with non-standard ERC20 tokens

```solidity
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

- Math library: Provides centralized mathematical operations, improving code maintainability while avoiding precision loss

```solidity
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// Usage example
liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
```

- Proxy contract library: Implements EIP-1967 standard proxy functionality

```solidity
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
```

#### 2.5.2 OpenZeppelin Contracts Upgradeable

The project also uses multiple upgradeable versions of OpenZeppelin contracts:

```solidity
import {
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    Initializable,
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/...";
```

Main upgradeable contract libraries include:

- Access Control:

```solidity
contract HannesExchangeV1Factory is AccessControlUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    function initialize() {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }
}
```

- Emergency Pause:

```solidity
contract HannesExchangeV1Pair is PausableUpgradeable {
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
}
```

- Reentrancy Protection:

```solidity
contract HannesExchangeV1Pair is ReentrancyGuardUpgradeable {
    function addLiquidity() external nonReentrant whenNotPaused {
        // Implementation
    }
}
```

- Initialization Pattern:

```solidity
function initialize() public initializer {
    __AccessControl_init();
    __Pausable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();
    __ERC20_init("HannesExchange LP Token", "HELP");
}
```

## 2. Development Tools

### 2.1 Integrated Development Environment: Visual Studio Code

This project uses Visual Studio Code for development. The following extensions are recommended for project development.

#### 2.2.1 Git and GitHub Support

- [Remote Repositories](https://marketplace.visualstudio.com/items?itemName=ms-vscode.remote-repositories)
- [GitHub Remote Repositories](https://marketplace.visualstudio.com/items?itemName=github.remotehub)
- [GitHub Pull Requests and Issues](https://marketplace.visualstudio.com/items?itemName=github.vscode-pull-request-github)

#### 2.2.2 Solidity and Foundry Support

- [Solidity](https://marketplace.visualstudio.com/items?itemName=juanblanco.solidity)
- [Even Better TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml)

> Note: Foundry's configuration file foundry.toml uses TOML syntax, hence the need for TOML syntax highlighting

#### 2.2.3 Python Support

- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [Debugpy](https://marketplace.visualstudio.com/items?itemName=ms-python.debugpy)
- [Pylance](https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-pylance)

> Note: While Python is not used as the development language in this project, Python scripts were used for repetitive tasks during development

#### 2.2.4 Code Formatting Tools

- [Black Formatter](https://marketplace.visualstudio.com/items?itemName=ms-python.black-formatter)
- [Prettier - Code formatter](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)

#### 2.2.5 Markdown and Related Support (for Project Documentation)

- [Markdown All in One](https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one)
- [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode)

> Note¹: All documentation in this project is written in Markdown, using Mermaid as the embedded diagram engine  

> Note²: The Marp plugin provides WYSIWYG real-time Markdown editing preview for VSCode

### 2.2 Smart Contract Development Framework: Foundry

The Foundry toolkit includes:

- Forge: Core compilation and testing tool
- Cast: Command-line tool for blockchain interaction
- Anvil: Local development network
- Chisel: Interactive development and debugging tool

### 2.3 Version Control: Git, GitHub

Project GitHub Repository: [HannesExchange](https://github.com/hannesgao/HannesExchange)


## 3. Development Environment Setup

### 3.1 Installing Solidity Compiler solc

This project uses npm (Node.js package manager) to install the Portable version of solc:

```bash
npm install -g solc
```

For Linux/Unix-like development environments, it's recommended to install the solc compiler using the distribution's package manager.

For example, on MacOS using HomeBrew package manager:

```bash
brew update
brew upgrade
brew tap ethereum/ethereum
brew install solidity
```

### 3.2 Installing Rust Compiler and Cargo Package Manager

Since Foundry is written in Rust, offering faster execution speed compared to traditional JavaScript testing frameworks, we need to install the Rust compiler before proceeding with Foundry and its toolchain installation.

It's recommended to use the official installation tool [`rustup.rs`](https://rustup.rs/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

After installation, use the `rustup` command to verify Rust is up to date and attempt updates:

```bash
rustup update
``` 

### 3.3 Installing Foundry Toolchain

It's recommended to use the official installation tool [Foundryup](https://github.com/foundry-rs/foundry/blob/master/foundryup/README.md):

```bash
# Download and execute Foundryup installation script
curl -L https://foundry.paradigm.xyz | bash

# Run Foundryup
foundryup
```

Alternatively, you can compile and install using Cargo package manager from Foundry's GitHub Repo:

```bash
# Install four components of Foundry toolchain using Cargo package manager
cargo install --git https://github.com/foundry-rs/foundry --profile release --locked forge cast chisel anvil

# forge:  Core component of testing framework
# cast:   Command-line tool for executing transactions and viewing contract state
# chisel: For interactive smart contract development and debugging
# anvil:  For deploying local Ethereum simulation chain
```

### 3.4 Cloning Project and Installing Dependencies

```bash
# Clone project repository locally
git clone https://github.com/hannesgao/HannesExchange.git

# Install project dependencies using forge
forge install
```

### 3.5 Configuring Project Environment Variables
```bash
# Edit .env file, fill in necessary environment variables
cp .env.example .env
```

#### 3.5.1 Required Environment Variables for Deployment

```bash
# Test network RPC node
SEPOLIA_RPC_URL=<your-sepolia-rpc-url>

# Private keys of test accounts for deployment, multiple can be added as needed
PRIVATE_KEY_1=<your-private-key-1>
PRIVATE_KEY_1=<your-private-key-1>

# EtherScan API-Key for verifying deployed contracts
ETHERSCAN_API_KEY=<your-etherscan-api-key>
```

### 3.6 Compiling Contracts

```bash
forge build
```

### 3.7 Running Tests

```bash
# The -v parameter in forge test command represents the verbosity level of test execution logs
# -vvvvv displays all available information, including detailed transaction info, stack traces, and debug output

forge test -vvvvv

# This option is very helpful for locating problematic functions in test cases or original contracts
```

## 4. Code Style Guidelines: Solidity Code Style

### 4.1 Version Declaration

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
```

### 4.2 Import Style

This project uses **named imports**, following this format:

```solidity
import { Contract1, Contract2, ... } from "contract-path";
```

Named imports are an import method from the ES6 module system, allowing import of specifically named parts from a module.

> Note: Unlike default imports, named imports allow importing multiple named exports from a module, such as multiple contracts from a single .sol file

### 4.3 Comment Guidelines

#### 4.3.1 NatSpec Comment Format

This project uses [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html) format comments, where:

- All public functions must have complete comments
- Critical internal functions also need comments
- Add specific security comments for code implementing security mechanisms

For example:

```solidity
/**
 * @title Contract Name
 * @dev Contract Description
 * @notice User-readable explanation
 */
```
```solidity
/**
 * @dev Function description
 * @param paramName Parameter description
 * @return Return value description
 */
```

### 4.4 Variable Naming Conventions

#### 4.4.1 State Variables: Use Camel Case

```solidity
/// State variables, use camelCase
uint256 public totalSupply; 
address private ownerAddress;
```

#### 4.4.2 Local Variables: Use Camel Case

```solidity
function exampleFunction(uint256 inputValue) public {
    /// Local variables, use camelCase
    uint256 localVariable = inputValue + 1; 
}
```

#### 4.4.3 Constants: Use Upper Case with Underscores

```solidity
/// Constants, use UPPER_CASE with underscores
uint256 public constant MAX_SUPPLY = 1000000; 
address private constant ZERO_ADDRESS = address(0); 
```

#### 4.4.4 Events: Use Pascal Case

```solidity
/// Events, use PascalCase
event TokensMinted(address indexed to, uint256 amount); 
event OwnershipTransferred(address indexed owner, address indexed newOwner);
```

#### 4.4.5 Modifiers: Use Camel Case

```solidity
/// Modifiers, use camelCase
modifier onlyOwner() {
    require(msg.sender == ownerAddress, "Not the contract owner"); 
    _;
}
```

## 5. Contract Architecture

### 5.1 Core Contract Versions

#### 5.1.1 HannesExchangeV1 Core Contracts
- `HannesExchangeV1Factory.sol`: Factory contract managing all `ETH ↔ ERC20` liquidity pools
- `HannesExchangeV1Pair.sol`: Liquidity pool contract implementing `ETH ↔ ERC20` exchange functionality

#### 5.1.2 HannesExchangeV2 Core Contracts
- `HannesExchangeV2Factory.sol`: Improved factory contract supporting `ERC20 ↔ ERC20` liquidity pools
- `HannesExchangeV2Pair.sol`: Improved liquidity pool contract implementing `ERC20 ↔ ERC20` exchange functionality

### 5.2 Contract Role Design

#### 5.2.1 Factory Contract Roles
- `DEFAULT_ADMIN_ROLE`: Highest privilege role
- `UPGRADER_ROLE`: Contract upgrade permission
- `PAUSER_ROLE`: Emergency pause permission
- `EXCHANGE_CREATOR_ROLE`: Liquidity pool creation permission

#### 5.2.2 Liquidity Pool Contract Roles
- `DEFAULT_ADMIN_ROLE`: Role with highest privileges
- `UPGRADER_ROLE`: Role authorized for contract upgrades
- `PAUSER_ROLE`: Role authorized for emergency pauses

## 6. Contract Deployment

Contract deployment scripts are stored in the [/script](../script) directory, with files named as `DeployContractName.s.sol`.

### 6.1 Deploying HannesExchangeV1 Core Contracts

#### 6.1.1 Pre-deployment Checklist

- Modify EOA and contract addresses in deployment scripts as needed
- Configure deployment test EOA private keys and EtherScan API key in .env and foundry.toml
- Ensure .env is listed in .gitignore to prevent syncing private keys and API keys to remote repository

#### 6.1.2 Deploy HannesExchangeV1 Factory Contract

```bash
forge script script/DeployHannesExchangeV1Factory.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

#### 6.1.3 Deploy HannesExchangeV1 Liquidity Pool Contract

```bash
forge script script/DeployHannesExchangeV1Pair.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

## 7. Analysis of Upgrade Strategy to HannesExchangeV2

### 7.1 Architectural Change Analysis

#### 7.1.1 Liquidity Pool Model Changes

- `HannesExchangeV1Pair`: Uses `ETH` as base currency, supports only direct `ETH ↔ ERC20` exchanges
- `HannesExchangeV2Pair`: Supports any `ERC20` token pairs, removes `ETH` base currency restriction
   
#### 7.1.2 Liquidity Pool State Variable Layout Changes

`HannesExchangeV1Pair` state variable layout:

```solidity
/// Single ERC20 token address
address public tokenAddress;

/// Factory contract address
address public factoryAddress;
```

`HannesExchangeV2Pair` state variable layout:

```solidity
/// Factory contract address
address public factoryAddress;

/// Token pair addresses in liquidity pool
IERC20 public token0;
IERC20 public token1;

/// Reserves for tracking token balances
uint256 public reserve0;
uint256 public reserve1;

/// Last on-chain timestamp of reserve update
uint256 private blockTimestampLast;
```

#### 7.1.3 Factory Contract Mapping Changes

`HannesExchangeV1Factory` mappings:

```solidity
mapping(address => address) public tokenToExchange;  /// token => pair
mapping(address => address) public exchangeToToken;  /// pair => token
mapping(uint256 => address) public idToToken;        /// id => token
address[] public allExchanges;
```

`HannesExchangeV2Factory` mappings:

```solidity
mapping(address => mapping(address => address)) public getPair;  
/// token0 => token1 => pair
```

### 7.2 Implementation Differences Analysis

#### 7.2.1 Price Calculation Mechanism
- `HannesExchangeV1Pair`: Simpler calculations using ETH as base currency
- `HannesExchangeV2Pair`: Direct price calculation for any token pair, requiring more complex mathematical models

#### 7.2.2 Liquidity Management Mechanism
- `HannesExchangeV1Pair`: Unidirectional liquidity addition and removal
- `HannesExchangeV2Pair`: Introduces more complex liquidity management mechanisms, including minimum liquidity locking

### 7.3 Reference: Uniswap V1 to V2 Upgrade Practices

#### 7.3.1 Independent Deployment vs. Upgrade
- Uniswap V1 and V2 use completely independent contract systems
- Maintain Uniswap V1 operation while deploying new Uniswap V2 system

#### 7.3.2 Liquidity Migration Mechanism
- Provide liquidity migration tools
- Allow users to choose migration timing
- No forced immediate migration

#### 7.3.3 Parallel Operation Period
- Run Uniswap V1 and Uniswap V2 simultaneously
- Provide adequate migration time for users and integrators

#### 7.3.4 Architectural Restructuring
- Uniswap V1: Uses `ETH` as intermediary for indirect `ERC20 ↔ ERC20` exchanges
- Uniswap V2: Introduces generic `ERC20` token pairs with `ETH-Wrapper` for `ETH ↔ ERC20` exchanges

#### 7.3.5 Contract Independence
- Each Uniswap version uses independent factory contracts
- Deploy new logic factory contracts instead of upgrading existing ones

### 7.4 Rationale: Why HannesExchangeV2 Should Be Independently Deployed

#### 7.4.1 Technical Reasons

- **Storage Layout Changes**: HannesExchangeV2 introduces new state variables and modifies existing mapping structures, creating storage layout incompatibilities. UUPS proxy pattern upgrades require compatible storage layouts.
- **Core Architecture Changes**: Transition from `ETH ↔ ERC20` to `ERC20 ↔ ERC20` requires core logic rewrite and fundamental changes to liquidity pool price calculation mechanisms.
- **Function Interface Changes**: HannesExchangeV2 introduces new function interfaces and modifies existing parameter structures.

#### 7.4.2 Business Considerations

- **User Impact Mitigation**: Independent deployment allows continued use of HannesExchangeV1 contracts, avoiding forced upgrade risks
- **Ecosystem Compatibility**: Projects integrated with HannesExchangeV1 need adaptation time; parallel operation enables smooth transition
- **Risk Control**: Separate deployment reduces upgrade risks, isolating potential issues from affecting the entire system

## 8. Deployment Recommendations for HannesExchangeV2

### 8.1 Recommendation: Independent Deployment of HannesExchangeV2 Core Contracts

#### 8.1.1 Pre-deployment Checklist

- Modify EOA and contract addresses in deployment scripts as needed
- Configure deployment test EOA private keys and EtherScan API key in .env and foundry.toml
- Ensure .env is listed in .gitignore to prevent syncing private keys and API keys to remote repository

#### 8.1.2 Deploy HannesExchangeV2 Factory Contract

```bash
forge script script/DeployHannesExchangeV2Factory.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

#### 8.1.3 Deploy HannesExchangeV2 Liquidity Pool Contract

```bash
forge script script/DeployHannesExchangeV2Pair.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

### 8.2 Recommendation: Post-deployment Liquidity Migration

#### 8.2.1 Provide Migration Tools
- Develop liquidity migration contracts (TO-DO)
- Provide migration guides and tools (TO-DO)

#### 8.2.2 Technical Documentation Updates
- Update technical documentation
- Provide migration tutorials
- Document differences between HannesExchangeV1 and HannesExchangeV2

## 9. Testing Standards

Contract test suites are stored in the [/test](../test) directory, with files named as `ContractName.t.sol`. Each test suite includes multiple test cases and implements the following four types of tests as needed:

### 9.1 Unit Tests

Use Foundry's testing framework to test each independent contract functionality (function)

### 9.2 Integration Tests

Test contract interactions to simulate real-world operation flows

### 9.3 Fuzz Tests

Use Foundry's fuzzing capabilities to test edge cases and exceptional conditions

### 9.4 Upgrade Tests

Test contract upgrade correctness and verify state variable preservation

## 10. Future Development Recommendations for HannesExchangeV2

### 10.1 Feature Extensions
- Implement complete `Router - Factory - Pair/Pool` architecture
- Introduce `Router` contract with `ETH-wrapper` logic
- Implement price oracle integration
- Add liquidity mining functionality
- Implement flash loan capabilities

### 10.2 Security Enhancements
- Conduct regular security audits
- Implement additional security mechanisms
- Improve error handling mechanisms

### 10.3 Performance Optimizations
- Continuously optimize gas consumption
- Improve mathematical computation methods
- Optimize storage structures (e.g., use uint112 for reserves like Uniswap V2 to save storage space)

### 10.4 Documentation Maintenance
- Keep documentation up-to-date
- Add more test case documentation
- Enhance technical documentation