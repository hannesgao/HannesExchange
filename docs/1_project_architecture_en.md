# Project Architecture Overview  
This project implements an advanced, secure, and upgradable Automated Market Maker (AMM) platform using **UUPS (Universal Upgradeable Proxy Standard)** to separate logic and storage, while optimizing Gas usage efficiency. It also incorporates multi-layered security mechanisms, including slippage control, emergency stop functionality, and access management.  

The architecture of this project is based on the Uniswap V2 codebase, with added new features as described above.

---  

## Module Description  

### Core Interfaces  
- **ICallee**: Contract caller (user) interface  
- **IERC20**: ERC20 standard token interface  
- **IFactory**: Liquidity pool factory interface for creating liquidity pools  
- **IPair**: Single liquidity pool interface, supporting ETH and ERC20 token swaps  

### Core Contracts  
#### **Factory**  
- Creates and manages multiple liquidity pools  
- Records all liquidity pool addresses, supports querying pools by token pairs  

#### **Pair**  
- Single liquidity pool contract, supporting token swaps and liquidity management  
- Implements slippage control, fee reward mechanism, and dynamic pricing  
- Manages access control via **AccessControlUpgradeable**  

---  

## Security Mechanisms  
1. **Prevention of Reentrancy Attacks**: Uses OpenZeppelin's `nonReentrant` modifier  
2. **Emergency Stop Functionality**: Uses OpenZeppelin's `PausableUpgradeable`  
3. **Gas Optimization**: Reduces state variable updates and simplifies event logs  
4. **Upgrade Management**: Limits upgrade permissions via `UPGRADER_ROLE`  

---  

## Separation of Storage and Logic  
The **UUPS** model is used to separate storage and logic, where storage variables are kept in the Proxy and logic resides in the implementation contract. The upgrade process is as follows:

### Initialize Storage  
- The Proxy's constructor specifies the initial logic contract  
- The `initialize` method is called to allocate roles and perform initial setup  

### Replace Logic  
- A new logic contract is deployed to the Proxy via the `upgradeTo` method  
- Ensures the integrity of Proxy's storage variables