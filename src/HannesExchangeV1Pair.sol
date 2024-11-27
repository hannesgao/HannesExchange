/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title HannesExchangeV1Pair
 * @dev 一个可升级的流动性池（ETH-ERC20 Token Pair）实现，支持ETH和ERC20代币之间的交换
 * @notice 实现了基于角色的访问控制、可升级性和紧急停止功能
 */
contract HannesExchangeV1Pair is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// 角色定义
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// 状态变量
    address public tokenAddress;
    address public factoryAddress;

    /// 事件声明
    event LiquidityAdded(
        address indexed provider,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 ethAmount,
        uint256 tokenAmount
    );

    event TokenPurchased(
        address indexed buyer,
        uint256 ethAmount,
        uint256 tokensReceived
    );

    event TokenSold(
        address indexed seller,
        uint256 tokensSold,
        uint256 ethReceived
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        /// 防止在实现合约上进行初始化
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数
     * @param _tokenAddress ERC20代币地址
     * @param _admin 管理员地址
     */
    function initialize(
        address _tokenAddress,
        address _admin,
        address _upgrader,
        address _pauser
    ) public initializer {
        require(_tokenAddress != address(0), "Token address cannot be 0");
        require(_admin != address(0), "Admin address cannot be 0");
        require(_upgrader != address(0), "Upgrader address cannot be 0");
        require(_pauser != address(0), "Pauser address cannot be 0");

        /// 初始化基础合约
        __ERC20_init("HannesExchange LP Token", "HELP");
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        /// 设置状态变量
        tokenAddress = _tokenAddress;
        factoryAddress = msg.sender;

        /// 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);
        _grantRole(PAUSER_ROLE, _pauser);
    }

    /**
     * @dev 紧急暂停合约
     * @notice 只有具有PAUSER_ROLE的地址可以调用
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev 解除合约暂停
     * @notice 只有具有PAUSER_ROLE的地址可以调用
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev 获取合约中代币储备量
     */
    function getTokenReserves() public view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /**
     * @dev 计算购买代币所需的ETH数量
     * @param ethSold 需要卖出的ETH数量
     */
    function getTokenAmount(uint256 ethSold) public view returns (uint256) {
        require(ethSold > 0, "ETH sold must be greater than 0");
        uint256 ethReserve = address(this).balance;
        uint256 tokenReserve = getTokenReserves();
        return
            getAmount(
                ethSold,
                ethReserve, // 使用当前的ETH储备量
                tokenReserve // 使用当前的代币储备量
            );
    }

    /**
     * @dev 计算卖出代币可得的ETH数量
     * @param tokensSold 想要卖出的代币数量
     */
    function getEthAmount(uint256 tokensSold) public view returns (uint256) {
        require(tokensSold > 0, "Tokens sold must be greater than 0");
        uint256 tokenReserve = getTokenReserves();
        uint256 ethReserve = address(this).balance;
        return
            getAmount(
                tokensSold,
                tokenReserve, // 使用当前的代币储备量
                ethReserve // 使用当前的ETH储备量
            );
    }

    /**
     * @dev 基于恒定乘积公式计算交换数量
     * @notice 包含0.3%的交易费用
     */
    function getAmount(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(
            inputReserve > 0 && outputReserve > 0,
            "Insufficient reserve"
        );
        require(inputAmount > 0, "Invalid input amount");

        // 计算交易费用（0.3%）
        uint256 inputAmountWithFee = inputAmount * 997;
        // 计算分子
        uint256 numerator = inputAmountWithFee * outputReserve;
        // 计算分母
        uint256 denominator = (inputReserve * 1000) + inputAmountWithFee;
        // 返回计算结果
        return numerator / denominator;
    }

    /**
     * @dev 添加流动性
     * @param tokensAdded 添加的代币数量
     * @notice 合约必须未暂停
     * @notice 包含重入防护
     */
    function addLiquidity(
        uint256 tokensAdded
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(msg.value > 0 && tokensAdded > 0, "Invalid values provided");

        uint256 ethBalance = address(this).balance - msg.value; /// Gas优化：避免多次调用address(this).balance
        uint256 tokenBalance = getTokenReserves();

        uint256 liquidity;
        if (tokenBalance == 0) {
            require(
                IERC20(tokenAddress).balanceOf(msg.sender) >= tokensAdded,
                "Insufficient token balance"
            );

            /// 使用SafeERC20进行安全转账
            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokensAdded
            );
            liquidity = msg.value;
            _mint(msg.sender, liquidity);
        } else {
            liquidity = (msg.value * totalSupply()) / ethBalance;
            require(
                IERC20(tokenAddress).balanceOf(msg.sender) >= tokensAdded,
                "Insufficient token balance"
            );

            /// 使用SafeERC20进行安全转账
            IERC20(tokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokensAdded
            );
            _mint(msg.sender, liquidity);
        }

        emit LiquidityAdded(msg.sender, msg.value, tokensAdded);
        return liquidity;
    }

    /**
     * @dev 移除流动性
     * @param tokenAmount 要移除的LP代币数量
     * @notice 合约必须未暂停
     * @notice 包含重入防护
     */
    function removeLiquidity(
        uint256 tokenAmount
    ) external nonReentrant whenNotPaused returns (uint256, uint256) {
        require(tokenAmount > 0, "Invalid token amount");
        require(totalSupply() > 0, "No liquidity");

        /// Gas优化：缓存状态变量
        uint256 totalTokenSupply = totalSupply();
        uint256 ethBalance = address(this).balance;
        uint256 tokenReserve = getTokenReserves();

        uint256 ethAmount = (ethBalance * tokenAmount) / totalTokenSupply;
        uint256 tokenAmt = (tokenReserve * tokenAmount) / totalTokenSupply;

        /// 验证恒定乘积
        require(
            (tokenReserve * ethBalance) >=
                ((tokenReserve - tokenAmt) * (ethBalance - ethAmount)),
            "Invariant check failed"
        );

        _burn(msg.sender, tokenAmount);

        /// 使用低级call进行ETH转账，捕获任何可能的失败
        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        /// 使用SafeERC20进行安全转账
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmt);

        emit LiquidityRemoved(msg.sender, ethAmount, tokenAmt);
        return (ethAmount, tokenAmt);
    }

    /**
     * @dev 用ETH换取代币
     * @param minTokens 最少接收的代币数量（滑点保护）
     * @param recipient 接收代币的地址
     * @notice 合约必须未暂停
     * @notice 包含重入防护
     */
    function swapEthForTokens(
        uint256 minTokens,
        address recipient
    ) external payable nonReentrant whenNotPaused returns (uint256) {
        require(recipient != address(0), "Invalid recipient");
        require(msg.value > 0, "Insufficient ETH sent");

        uint256 tokenReserve = getTokenReserves();

        // 使用扣除掉当前交易的ETH后的储备量来计算
        uint256 tokenAmount = getAmount(
            msg.value,
            address(this).balance - msg.value, // 当前合约的ETH余额减去新转入的ETH
            tokenReserve
        );

        require(tokenAmount >= minTokens, "Insufficient output amount");

        // 使用SafeERC20进行安全转账
        IERC20(tokenAddress).safeTransfer(recipient, tokenAmount);

        emit TokenPurchased(msg.sender, msg.value, tokenAmount);
        return tokenAmount;
    }

    /**
     * @dev 用代币换取ETH
     * @param tokensSold 卖出的代币数量
     * @param minEth 最少接收的ETH数量（滑点保护）
     * @notice 合约必须未暂停
     * @notice 包含重入防护
     */
    function swapTokenForEth(
        uint256 tokensSold,
        uint256 minEth
    ) external nonReentrant whenNotPaused returns (uint256) {
        uint256 ethAmount = getEthAmount(tokensSold);
        require(ethAmount >= minEth, "Insufficient output amount");

        /// 使用SafeERC20进行安全转账
        IERC20(tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            tokensSold
        );

        /// 使用低级call进行ETH转账，捕获任何可能的失败
        (bool success, ) = payable(msg.sender).call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        emit TokenSold(msg.sender, tokensSold, ethAmount);
        return ethAmount;
    }

    /**
     * @dev 实现UUPS升级授权检查
     * @param implementation 新的实现合约地址
     */
    function _authorizeUpgrade(
        address implementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    /**
     * @dev 查看合约版本
     * @notice 用于验证升级是否成功
     */
    function version() public pure virtual returns (string memory) {
        return "1.0.0";
    }
}
