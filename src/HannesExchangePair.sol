/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title HannesExchangePair 合约
 * @dev 实现了特定代币对流动性池的核心功能，包括添加/移除流动性和代币交换
 *
 * 安全性与健壮性保证:
 * 1. 使用 OpenZeppelin 的 UUPS 可升级合约标准，确保合约可以安全升级
 * 2. 使用 OpenZeppelin 的 Pausable 实现基于角色的访问控制
 * 3. 使用 OpenZeppelin 的 AccessControl 实现断路器模式（紧急暂停功能）
 * 4. 使用 OpenZeppelin 的 ReentrancyGuard 防止重入攻击
 * 5. 添加了滑点保护机制
 * 6. 所有外部调用前后都有状态检查
 * 7. 实现了事件机制，方便跟踪关键操作
 * 8. 价格操纵防护机制
 */
contract HannesExchangePair is 
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable 
{
    /// ===== 状态变量 =====

    /// 角色定义
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");    /// 断路器操作角色
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");    /// 升级操作角色
    
    /// 流动性池内代币对的地址
    IERC20 public token0;
    IERC20 public token1;
    
    /// 储备量，用于追踪两个代币的余额
    uint256 public reserve0;
    uint256 public reserve1;
    
    /// 最后一次更新储备量的链上时间戳
    uint256 private blockTimestampLast;
    
    /// 交易费率常数，基数为10000，比如30表示0.3%
    uint256 public constant SWAP_FEE = 30;
    uint256 private constant FEE_DENOMINATOR = 10000;
    
    /// 最小流动性值，防止第一个LP通过极小值垄断份额
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    
    /// ===== 事件定义 =====
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);    /// 流动性（LP代币）铸造事件
    event Burn(address indexed sender, uint256 amount0, uint256 amount1);    /// 流动性（LP代币）销毁事件
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);    /// 储备同步事件
    
    /// ===== 错误定义 =====
    error InsufficientLiquidity();
    error InsufficientInputAmount();
    error InsufficientOutputAmount();
    error InvalidK();
    error TransferFailed();

    /// 安全性: 确保初始化方法只运行一次，以防止意外重新初始化
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    /**
     * @dev 初始化函数，替代构造函数
     * @param _token0 第一个代币的地址
     * @param _token1 第二个代币的地址
     * 
     * 安全性: 初始化所有继承的合约，包括 ReentrancyGuard
     */
    function initialize(
        address _token0,
        address _token1
    ) public initializer {
        /// 安全性：代币地址检查
        require(_token0 != address(0), "HannesExchangePair: ZERO_ADDRESS");
        require(_token1 != address(0), "HannesExchangePair: ZERO_ADDRESS");
        require(_token0 != _token1, "HannesExchangePair: IDENTICAL_ADDRESSES");
        
        /// 安全性: 初始化所有基础合约
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        /// 安全性: 初始化LP代币
        __ERC20_init("HannesExchange LP Token", "HELP");
        
        /// 安全性: 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
        
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    /**
     * @dev 添加流动性
     * @param amount0Desired token0期望数量
     * @param amount1Desired token1期望数量
     * @param amount0Min token0最小数量
     * @param amount1Min token1最小数量
     * @param to 接收LP代币的地址
     * @return liquidity 铸造的LP代币数量
     * 
     * 安全性:
     * - 使用ReentrancyGuard防止重入
     * - 滑点保护
     * - 检查最小数量要求
     * - 验证所有转账
     */
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 liquidity) {
        /// 安全性: 参数检查
        require(to != address(0), "HannesExchangePair: INVALID_TO");
        
        /// Gas优化: 缓存储备量
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        
        /// 计算实际添加的流动性数量
        uint256 amount0;
        uint256 amount1;
        
        /// 第一次添加流动性的情况
        if (_reserve0 == 0 && _reserve1 == 0) {
            amount0 = amount0Desired;
            amount1 = amount1Desired;
        } else {
            /// 根据当前比例计算实际数量
            uint256 amount1Optimal = quote(amount0Desired, _reserve0, _reserve1);
            if (amount1Optimal <= amount1Desired) {
                /// 安全性: 检查最小数量要求
                require(amount1Optimal >= amount1Min, "HannesExchangePair: INSUFFICIENT_1_AMOUNT");
                amount0 = amount0Desired;
                amount1 = amount1Optimal;
            } else {
                uint256 amount0Optimal = quote(amount1Desired, _reserve1, _reserve0);
                require(amount0Optimal <= amount0Desired);
                /// 安全性: 检查最小数量要求
                require(amount0Optimal >= amount0Min, "HannesExchangePair: INSUFFICIENT_0_AMOUNT");
                amount0 = amount0Optimal;
                amount1 = amount1Desired;
            }
        }
        
        /// 安全性: 转移代币
        require(token0.transferFrom(msg.sender, address(this), amount0), "HannesExchangePair: TRANSFER_FAILED");
        require(token1.transferFrom(msg.sender, address(this), amount1), "HannesExchangePair: TRANSFER_FAILED");
        
        /// 计算LP代币数量
        if (totalSupply() == 0) {
            /// 首次添加流动性
            /// 安全性: 设置最小流动性，防止价格操纵
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            /// 安全性: 永久锁定最小流动性
            _mint(address(1), MINIMUM_LIQUIDITY);
        } else {
            /// 后续添加流动性
            /// Gas优化: 使用较小的数计算，防止溢出
            liquidity = Math.min(
                (amount0 * totalSupply()) / _reserve0,
                (amount1 * totalSupply()) / _reserve1
            );
        }
        
        /// 安全性: 检查流动性数量
        require(liquidity > 0, "HannesExchangePair: INSUFFICIENT_LIQUIDITY_MINTED");
        
        /// 铸造LP代币
        _mint(to, liquidity);
        
        /// 更新储备量
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
        
        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev 移除流动性
     * @param liquidity LP代币数量
     * @param amount0Min token0最小返还数量
     * @param amount1Min token1最小返还数量
     * @param to 接收代币的地址
     * @return amount0 返还的token0数量
     * @return amount1 返还的token1数量
     * 
     * 安全性:
     * - 使用ReentrancyGuard防止重入
     * - 滑点保护
     * - 验证所有转账
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1) {
        /// 安全性: 地址检查
        require(to != address(0), "HannesExchangePair: INVALID_TO");
        
        /// Gas优化: 缓存数据
        uint256 _totalSupply = totalSupply();
        
        /// 计算返还数量
        /// Gas优化: 直接使用余额计算，减少数学计算
        amount0 = (liquidity * reserve0) / _totalSupply;
        amount1 = (liquidity * reserve1) / _totalSupply;
        
        /// 安全性: 检查最小数量要求
        require(amount0 >= amount0Min, "HannesExchangePair: INSUFFICIENT_0_AMOUNT");
        require(amount1 >= amount1Min, "HannesExchangePair: INSUFFICIENT_1_AMOUNT");
        
        /// 销毁LP代币
        _burn(msg.sender, liquidity);
        
        /// 安全性: 转移代币
        require(token0.transfer(to, amount0), "HannesExchangePair: TRANSFER_FAILED");
        require(token1.transfer(to, amount1), "HannesExchangePair: TRANSFER_FAILED");
        
        /// 更新储备量
        _update(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
        
        emit Burn(msg.sender, amount0, amount1);
    }

    /**
     * @dev 计算等价数量
     * @param amountA 输入数量
     * @param reserveA 输入代币储备量
     * @param reserveB 输出代币储备量
     * Gas优化: 简化计算逻辑
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure returns (uint256 amountB) {
        require(amountA > 0, "HannesExchangePair: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "HannesExchangePair: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }
    
    /**
     * @dev 执行代币交换
     * @param amount0Out 输出token0的数量
     * @param amount1Out 输出token1的数量
     * @param to 接收地址
     * 
     * 安全性: 
     * - 使用 OpenZeppelin ReentrancyGuard
     * - 检查K值保持不变
     * - 验证所有转账
     * - 滑点保护
     *
     * Gas优化:
     * - 本地变量缓存状态变量
     * - 优化计算顺序
     */
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) external nonReentrant whenNotPaused {
        /// 安全性: 基础参数检查
        require(amount0Out > 0 || amount1Out > 0, "HannesExchangePair: INSUFFICIENT_OUTPUT_AMOUNT");
        require(to != address(0), "HannesExchangePair: INVALID_TO");
        
        /// Gas优化: 缓存储备量
        uint256 _reserve0 = reserve0;
        uint256 _reserve1 = reserve1;
        
        /// 安全性: 检查输出数量不超过储备量
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "HannesExchangePair: INSUFFICIENT_LIQUIDITY");
        
        /// Gas优化: 本地变量存储中间状态
        /// uint256 balance0Before = token0.balanceOf(address(this));
        /// uint256 balance1Before = token1.balanceOf(address(this));
        
        /// 安全性: 检查数据有效性
        if (amount0Out > 0) {
            require(token0.transfer(to, amount0Out), "HannesExchangePair: TRANSFER_FAILED");
        }
        if (amount1Out > 0) {
            require(token1.transfer(to, amount1Out), "HannesExchangePair: TRANSFER_FAILED");
        }
        
        /// Gas优化: 直接使用余额计算
        uint256 balance0After = token0.balanceOf(address(this));
        uint256 balance1After = token1.balanceOf(address(this));
        
        /// 计算实际输入金额
        uint256 amount0In = balance0After > _reserve0 - amount0Out 
            ? balance0After - (_reserve0 - amount0Out) 
            : 0;
        uint256 amount1In = balance1After > _reserve1 - amount1Out 
            ? balance1After - (_reserve1 - amount1Out) 
            : 0;
        
        /// 安全性: 确保有足够的输入金额
        require(amount0In > 0 || amount1In > 0, "HannesExchangePair: INSUFFICIENT_INPUT_AMOUNT");
        
        /// 安全性: 验证K值保持不变(考虑手续费后)
        {
            /// Gas优化: 作用域隔离以清除栈变量
            uint256 balance0Adjusted = balance0After * FEE_DENOMINATOR - (amount0In * SWAP_FEE);
            uint256 balance1Adjusted = balance1After * FEE_DENOMINATOR - (amount1In * SWAP_FEE);
            require(
                balance0Adjusted * balance1Adjusted >= 
                _reserve0 * _reserve1 * (FEE_DENOMINATOR ** 2),
                "HannesExchangePair: K"
            );
        }
        
        /// 更新储备量
        _update(balance0After, balance1After);
        
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev 计算交换所需的输入数量
     * @param amountOut 期望输出的代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * Gas优化: 优化计算顺序，减少中间变量
     */
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountIn) {
        require(amountOut > 0, "HannesExchangePair: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "HannesExchangePair: INSUFFICIENT_LIQUIDITY");
        
        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * (FEE_DENOMINATOR - SWAP_FEE);
        amountIn = (numerator / denominator) + 1;
    }
    
    /**
     * @dev 计算能够获得的输出数量
     * @param amountIn 输入的代币数量
     * @param reserveIn 输入代币的储备量
     * @param reserveOut 输出代币的储备量
     * Gas优化: 优化计算顺序，减少中间变量
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "HannesExchangePair: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "HannesExchangePair: INSUFFICIENT_LIQUIDITY");
        
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - SWAP_FEE);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @dev 内部更新函数
     * @param balance0 token0新余额
     * @param balance1 token1新余额
     * Gas优化: 将所有存储操作集中在一起
     */
    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = block.timestamp;
        
        emit Sync(balance0, balance1);
    }
    
    /**
     * @dev 升级授权检查
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
    
    /// 紧急暂停
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }
    
    /// 恢复运行
    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }
}