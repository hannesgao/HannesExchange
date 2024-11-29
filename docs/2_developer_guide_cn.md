# HannesExchange 开发者指南

## 1. 项目概述

HannesExchange 是一个基于恒定乘积自动做市商模式的去中心化交易所的智能合约实现，包含 `HannesExchangeV1` 和 `HannesExchangeV2` 两个版本：

- `HannesExchangeV1`：`ETH` 作为基础货币，只支持 `ETH ↔ ERC20` 直接兑换
- `HannesExchangeV2`：任意 `ERC20` 代币对，移除了 `ETH` 作为基础货币的限制


## 2. 技术栈

### 2.1 智能合约开发语言：Solidity

本项目使用 Solidity 版本: `^0.8.28`，solc 编译器版本: `0.8.28+commit.7893614a.Emscripten.clang`

### 2.2 智能合约开发框架：Foundry

本项目开发时使用 Foundry 作为智能合约开发和测试框架，主要原因是 Foundry 与 Hardhat 相比执行速度更快，且可以直接使用 Solidity 语法来编写测试用例和部署脚本，可以提高测试和部署的效率。

### 2.3 测试网络：Ethereum Sepolia

本项目使用 Ethereum Sepolia 作为测试部署和智能合约的测试网

#### 2.3.1 测试网络设置

在 Foundry 项目配置文件 foundry.toml 中可设置 Sepolia 测试网的 RPC 地址： 

```TOML
[rpc_endpoints]
sepolia = "https://ethereum-sepolia-rpc.publicnode.com"
```

### 2.4 智能合约标准

#### 2.4.1 ERC-20 同质化代币

项目中对 ERC-20 标准的主要应用场景包括：

- LP 代币的实现

```solidity
contract HannesExchangeV1Pair is ERC20Upgradeable {
    function initialize() {
        __ERC20_init("HannesExchange LP Token", "HELP");
    }
}
```

- 与外部 ERC-20 代币的交互

```solidity
/// 使用 IERC20 接口与外部代币交互
IERC20 public token0;
IERC20 public token1;

/// 安全的 ERC20 代币转账
IERC20(tokenAddress).safeTransferFrom(
    msg.sender,
    address(this),
    tokensAdded
);
```

#### 2.4.2 EIP-1967 透明代理

项目使用 EIP-1967 标准实现合约的可升级性。

```solidity
/// 在工厂合约中部署新的交易对
ERC1967Proxy proxy = new ERC1967Proxy(
    address(exchangeImpl),
    initData
);
```

#### 2.4.3 ERC-1822 通用可升级代理

项目采用 UUPS（Universal Upgradeable Proxy Standard）代理模式：升级逻辑位于实现合约中，使用角色基础访问控制管理升级权限，支持合约逻辑的无缝升级。

```solidity
contract HannesExchangeV1Factory is UUPSUpgradeable {
    function _authorizeUpgrade(address implementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
```

### 2.5 外部标准合约库

#### 2.5.1 OpenZeppelin Contracts

项目使用了多个 OpenZeppelin 标准合约，包括：

- 代币合约库：用于安全的 ERC20 代币操作，处理非标准 ERC20 代币的兼容性问题

```solidity
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
```

- 数学运算库：提供集中的数学运算库，提升代码可维护性，同时避免精度损失

```solidity
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// 使用示例
liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
```

- 代理合约库：实现 EIP-1967 标准的代理功能

```solidity
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
```

#### 2.5.2 OpenZeppelin Contracts Upgradeable

项目也使用了多个可升级版本的 OpenZeppelin 合约：

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

主要使用的可升级合约库包含：

- 权限控制：

```solidity
contract HannesExchangeV1Factory is AccessControlUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    
    function initialize() {
        __AccessControl_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }
}
```

- 紧急暂停：

```solidity
contract HannesExchangeV1Pair is PausableUpgradeable {
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
}
```

- 重入保护：

```solidity
contract HannesExchangeV1Pair is ReentrancyGuardUpgradeable {
    function addLiquidity() external nonReentrant whenNotPaused {
        // 实现
    }
}
```

- 初始化模式：

```solidity
function initialize() public initializer {
    __AccessControl_init();
    __Pausable_init();
    __ReentrancyGuard_init();
    __UUPSUpgradeable_init();
    __ERC20_init("HannesExchange LP Token", "HELP");
}
```

## 2. 开发工具

### 2.1 集成开发环境：Visual Studio Code

本项目使用Visual Studio Code 开发，推荐为开发本项目安装以下插件

#### 2.2.1 添加 Git 和 GitHub 相关支持

- [Remote Repositories](https://marketplace.visualstudio.com/items?itemName=ms-vscode.remote-repositories)
- [GitHub Remote Repositories](https://marketplace.visualstudio.com/items?itemName=github.remotehub)
- [GitHub Pull Requests and Issues](https://marketplace.visualstudio.com/items?itemName=github.vscode-pull-request-github)

#### 2.2.2 添加 Solidity 和 Foundry 相关支持

- [Solidity](https://marketplace.visualstudio.com/items?itemName=juanblanco.solidity)
- [Even Better TOML](https://marketplace.visualstudio.com/items?itemName=tamasfe.even-better-toml)

> 注：Foundry 的配置文件 foundry.toml 使用 TOML 语法，因此需要 TOML 代码高亮

#### 2.2.3 添加 Python 支持

- [Python](https://marketplace.visualstudio.com/items?itemName=ms-python.python)
- [Debugpy](https://marketplace.visualstudio.com/items?itemName=ms-python.debugpy)
- [Pylance](https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-pylance)

> 注：本项目未使用 Python 作为开发语言，但在开发时的重复任务中使用了 Python 脚本

#### 2.2.4 代码格式化工具

- [Black Formatter](https://marketplace.visualstudio.com/items?itemName=ms-python.black-formatter)
- [Prettier - Code formatter](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode)

#### 2.2.5 Markdown 和相关支持（用于项目文档）

- [Markdown All in One](https://marketplace.visualstudio.com/items?itemName=yzhang.markdown-all-in-one)
- [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode)

> 注¹：本项目的所有文档都使用 Markdown 编写，并使用 Mermaid 作为文档内嵌图表引擎  

> 注²：Marp 插件可为 VSCode 提供所见即所得的 Markdown 实时编辑预览

### 2.2 智能合约开发框架：Foundry

Foundry 工具包中还包含：

- Forge：核心编译和测试工具
- Cast：与区块链交互的命令行工具
- Anvil：本地开发网络
- Chisel：交互式开发和调试工具

### 2.3 版本控制：Git，GitHub

本项目的 GitHub Repo：[HannesExchange](https://github.com/hannesgao/HannesExchange)


## 3. 开发环境搭建

### 3.1 安装 Solidity 编译器 solc

本项目开发时使用 Node.js 的包管理器 npm 安装 solc 的 Portable 版本：

```bash
npm install -g solc
```

推荐在 Linux / 类 Unix 开发环境下，使用该发行版的包管理器安装 solc 编译器。

例如，在 MacOS 下使用 HomeBrew 包管理器安装：

```bash
brew update
brew upgrade
brew tap ethereum/ethereum
brew install solidity
```

### 3.2 安装 Rust 编译器和 Rust 的包管理器 Cargo

由于 Foundry 是用 Rust 编写的，相比于传统的 JavaScript 测试框架，它的执行速度更快，能够更好地进行并发测试。因此，我们需要先安装 Rust 编译器，才能继续安装 Foundry 及其附属工具链。

建议直接使用官方建议的安装工具 [`rustup.rs`](https://rustup.rs/) 来安装：

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

安装完毕后，使用 `rustup` 命令来验证 Rust 是否是最新的版本，并尝试更新：

```bash
rustup update
``` 

### 3.3 安装 Foundry 工具链

建议使用官方建议的安装工具 [Foundryup](https://github.com/foundry-rs/foundry/blob/master/foundryup/README.md) 来安装：

```bash
# 下载 Foundryup 安装脚本并执行
curl -L https://foundry.paradigm.xyz | bash

# 运行 Foundryup
foundryup
```

也可以使用 Cargo 包管理器从 Foundry 的 GitHub Repo 编译并安装：

```bash
# 使用 Cargo 包管理器安装 Foundry 工具链中的四个组件
cargo install --git https://github.com/foundry-rs/foundry --profile release --locked forge cast chisel anvil

# forge:  测试框架的核心组件
# cast:   用于执行交易和查看合约状态的命令行工具
# chisel: 用于进行智能合约的交互式开发和调试
# anvil:  用于部署本地的以太坊模拟链
```

### 3.4 克隆本项目并安装依赖

```bash
# 克隆项目仓库到本地
git clone https://github.com/hannesgao/HannesExchange.git

# 使用 forge 安装项目依赖
forge install
```

### 3.5 配置项目环境变量
```bash
# 编辑 .env 文件，填入必要的环境变量
cp .env.example .env
```

#### 3.5.1 本项目中在部署时必要的环境变量

```bash
# 测试网 RPC 节点
SEPOLIA_RPC_URL=<your-sepolia-rpc-url>

# 部署用测试账户的私钥，可按需写入多个
PRIVATE_KEY_1=<your-private-key-1>
PRIVATE_KEY_1=<your-private-key-1>

# EtherScan API-Key，用于验证已部署的合约
ETHERSCAN_API_KEY=<your-etherscan-api-key>
```

### 3.6 编译合约

```bash
forge build
```

### 3.7 运行测试

```bash
# forge test 命令的 -v 参数代表测试运行过程中输出日志详细程度的设置
# -vvvvv 代表显示所有可用的信息，包括每个交易的详细信息，堆栈跟踪和调试输出

forge test -vvvvv

# 在运行合约测试用例时，该选项非常有益于定位测试用例或原合约中的问题函数位置
```

## 4. 代码风格规范：Solidity 代码风格

### 4.1 版本声明

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
```

### 4.2 导入风格

本项目中使用的导入方式是**命名导入**，即形如下方示例的导入方式：

```solidity
import { Contract1, Contract2, ... } from "contract-path";
```

命名导入 是 ES6 模块化系统中的一种导入方式，它允许从一个模块中导入特定命名的部分。

> 注：与默认导入不同，命名导入允许导入模块中多个具名的导出项，如一个 .sol 文件中的多个合约

### 4.3 注释规范

#### 4.3.1 NatSpec 注释规范

本项目使用 [NatSpec](https://docs.soliditylang.org/en/latest/natspec-format.html) 格式的注释，其中：

- 所有公共函数必须有完整的注释
- 关键的内部函数也需要注释
- 对于实现特定安全机制的代码，添加专门的安全性注释

形如：

```solidity
/**
 * @title 合约名
 * @dev 合约描述
 * @notice 用户可读的说明
 */
```
```solidity
/**
 * @dev 函数描述
 * @param paramName 参数描述
 * @return 返回值描述
 */
```

### 4.4 变量命名规范

#### 4.4.1 状态变量：使用驼峰命名法

```solidity
/// 状态变量，使用驼峰命名法
uint256 public totalSupply; 
address private ownerAddress;
```

#### 4.4.2 局部变量：使用驼峰命名法

```solidity
function exampleFunction(uint256 inputValue) public {
    /// 局部变量，使用驼峰命名法
    uint256 localVariable = inputValue + 1; 
}
```

#### 4.4.3 常量：使用大写字母和下划线

```solidity
/// 常量，使用大写字母和下划线
uint256 public constant MAX_SUPPLY = 1000000; 
address private constant ZERO_ADDRESS = address(0); 
```

#### 4.4.4 事件：使用帕斯卡命名法

```solidity
/// 事件，使用帕斯卡命名法
event TokensMinted(address indexed to, uint256 amount); 
event OwnershipTransferred(address indexed owner, address indexed newOwner);
```

#### 4.4.5 修饰器：使用小驼峰命名法

```solidity
/// 修饰器，使用小驼峰命名法
modifier onlyOwner() {
    require(msg.sender == ownerAddress, "Not the contract owner"); 
    _;
}
```

## 5. 合约架构

### 5.1 核心合约版本

#### 5.1.1 HannesExchangeV1 核心合约
- `HannesExchangeV1Factory.sol`：工厂合约，管理所有 `ETH ↔ ERC20` 流动性池
- `HannesExchangeV1Pair.sol`：流动性池合约，实现 `ETH ↔ ERC20` 交换功能

#### 5.1.2 HannesExchangeV2 核心合约
- `HannesExchangeV2Factory.sol`：改进的工厂合约，支持 `ERC20 ↔ ERC20` 流动性池
- `HannesExchangeV2Pair.sol`：改进的流动性池合约，实现 `ERC20 ↔ ERC20` 交换功能

### 5.2 合约角色设计

#### 5.2.1 工厂合约角色
- `DEFAULT_ADMIN_ROLE`：最高权限角色
- `UPGRADER_ROLE`：合约升级权限
- `PAUSER_ROLE`：紧急暂停权限
- `EXCHANGE_CREATOR_ROLE`：创建流动性池权限

#### 5.2.2 流动性池合约角色
- `DEFAULT_ADMIN_ROLE`：最高权限角色
- `UPGRADER_ROLE`：合约升级权限
- `PAUSER_ROLE`：紧急暂停权限


## 6. 合约部署

本项目中的合约部署脚本储存在 [/script](../script) 目录中，文件命名方式为 `DeployContractName.s.sol`

### 6.1 部署 HannesExchangeV1 核心合约

#### 6.1.1 部署前注意事项

- 部署前请按需修改部署脚本参数中的各种EOA以及合约账户地址
- 部署前请在 .env 以及 foundry.toml 中设置部署用测试 EOA 账户私钥和 EtherScan 的API秘钥
- 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和 API 秘钥不被同步至远程仓库

#### 6.1.2 部署 HannesExchangeV1 工厂合约

```bash
forge script script/DeployHannesExchangeV1Factory.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

#### 6.1.3 部署 HannesExchangeV1 流动性池合约

```bash
forge script script/DeployHannesExchangeV1Pair.s.sol \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

## 7. 升级到 HannesExchangeV2 的部署策略分析

### 7.1 架构变更差异分析

#### 7.1.1 流动性池的模型变化

- `HannesExchangeV1Pair`：`ETH` 作为基础货币，只支持 `ETH ↔ ERC20` 直接兑换
- `HannesExchangeV2Pair`：任意 `ERC20` 代币对，移除了 `ETH` 作为基础货币的限制
   
#### 7.1.2 流动性池的状态变量布局变化

`HannesExchangeV1Pair` 的状态变量布局：

```solidity
/// 单个 ERC20 代币地址
address public tokenAddress;

/// 工厂合约地址
address public factoryAddress;
```

`HannesExchangeV2Pair` 的状态变量布局：

```solidity
/// 工厂合约地址
address public factoryAddress;

/// 流动性池内代币对的地址
IERC20 public token0;
IERC20 public token1;

/// 储备量，用于追踪两个代币的余额
uint256 public reserve0;
uint256 public reserve1;

/// 最后一次更新储备量的链上时间戳
uint256 private blockTimestampLast;
```

#### 7.1.3 工厂合约映射关系

`HannesExchangeV1Factory` 的映射关系：

```solidity
mapping(address => address) public tokenToExchange;  /// token => pair
mapping(address => address) public exchangeToToken;  /// pair => token
mapping(uint256 => address) public idToToken;        /// id => token
address[] public allExchanges;
```

`HannesExchangeV2Factory` 的映射关系：

```solidity
mapping(address => mapping(address => address)) public getPair;  
/// token0 => token1 => pair
```

### 7.2 功能实现差异分析

#### 7.2.1 价格计算机制
- `HannesExchangeV1Pair`：使用 ETH 作为基础货币，计算相对简单
- `HannesExchangeV2Pair`：直接计算任意代币对的价格，需要更复杂的数学模型

#### 7.2.2 流动性管理机制
- `HannesExchangeV1Pair`：单向添加和移除流动性
- `HannesExchangeV1Pair`：引入更复杂的流动性管理机制，包括最小流动性锁定等

### 7.3 参考： Uniswap V1 到 V2 的升级实践

#### 7.3.1 独立部署而非升级
- Uniswap V1 和 V2 使用完全独立的合约系统
- 保持 Uniswap V1 继续运行，同时部署全新的 Uniswap V2 系统

#### 7.3.2 流动性迁移机制
- 提供流动性迁移工具
- 允许用户自主选择迁移时间
- 不强制用户立即迁移

#### 7.3.3 提供并行运行期
- Uniswap V1 和 Uniswap V2 同时运行一段时间
- 给予用户和集成方充足的迁移时间

#### 7.3.4 架构重构
- Uniswap V1: 使用 `ETH` 作为中间交易媒介以实现间接的 `ERC20 ↔ ERC20` 兑换
- Uniswap V2: 引入通用 `ERC20` 代币对，并用 `ETH-Warpper` 实现 `ETH ↔ ERC20` 兑换

#### 7.3.4 合约独立性
- Uniswap 的每个版本使用独立的工厂合约
- 部署新的逻辑工厂合约而不是升级现有合约

### 7.4 论证：为何 HannesExchangeV2 应该独立部署

#### 7.4.1 技术原因

- **存储布局变更**：HannesExchangeV2 引入了新的状态变量，改变了现有映射结构，导致了存储布局的变更和不兼容，而 UUPS 代理模式下的合约升级要求保持存储布局兼容
- **基础架构变更**：从 `ETH ↔ ERC20` 到 `ERC20 ↔ ERC20` 的转变需要重写大部分核心逻辑，且流动性池的价格计算机制发生根本变化
- **函数接口变更**：HannesExchangeV2 引入了新的函数接口，改变了现有函数的参数结构

#### 7.4.2 业务考虑

- **避免影响用户**：独立部署允许用户继续使用 HannesExchangeV1 合约，避免强制升级带来的风险
- **生态系统兼容**：已集成 HannesExchangeV1 的项目需要时间适配，并行运行有助于平滑过渡
- **控制升级风险**：分离部署降低升级风险，出现问题时不会影响整个系统

## 8. 升级到 HannesExchangeV2 的部署建议

### 8.1 建议：独立部署 HannesExchangeV1 核心合约

#### 8.1.1 部署前注意事项

- 部署前请按需修改部署脚本参数中的各种EOA以及合约账户地址
- 部署前请在 .env 以及 foundry.toml 中设置部署用测试 EOA 账户私钥和 EtherScan 的API秘钥
- 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和 API 秘钥不被同步至远程仓库

#### 8.1.2 部署 HannesExchangeV2 工厂合约

```bash
forge script script/DeployHannesExchangeV2.s.sol:DeployHannesExchangeV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

#### 8.1.3 部署 HannesExchangeV2 流动性池合约

```bash
forge script script/DeployHannesExchangeV2.s.sol:CreatePairV2 \
    --rpc-url sepolia \
    --broadcast \
    --verify
```

### 8.2 建议：部署后的流动性迁移

#### 8.2.1 提供迁移工具
- 开发流动性迁移合约（TO-DO）
- 提供迁移指南和工具（TO-DO）

#### 8.2.2 技术文档更新
- 更新技术文档
- 提供迁移教程
- 说明 HannesExchangeV1 和 HannesExchangeV2 的差异


## 9. 测试规范

本项目中的合约测试套件储存在 [/test](../test) 目录中，文件命名方式为 `ContractName.t.sol` ，每个合约测试套件中都集成了多个测试用例）。如有需求，本项目的每个测试套件都实现了下方的四种测试类型：

### 9.1 单元测试

使用 Foundry 的测试框架，测试每个独立的合约功能（函数）

### 9.2 集成测试

测试合约之间的交互，以模拟真实场景的操作流程

### 9.3 模糊测试

使用 Foundry 的模糊测试功能，测试边界条件和异常情况

### 9.4 升级测试

测试合约升级的正确性，验证状态变量的保持

## 10. 针对 HannesExchangeV2 后续开发的建议

### 10.1 功能扩展
- 实现完整的 `Router - Factory - Pair/Pool` 架构
- 引入含 `ETH-warper` 逻辑的 `Router` 合约
- 实现价格预言机集成
- 添加流动性挖矿功能
- 实现闪电贷功能

### 10.2 安全加强
- 定期进行安全审计
- 实现更多的安全防护机制
- 完善错误处理机制

### 10.3 性能优化
- 持续优化 Gas 消耗
- 改进数学计算方法
- 优化存储结构（如模仿 Uniswap V2 使用 uint112 来存储储备额，以节省存储空间）

### 10.4 文档维护
- 保持文档的及时更新
- 添加更多的测试用例说明
- 完善技术文档
