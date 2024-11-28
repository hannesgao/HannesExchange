/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./HannesExchangeV2Pair.sol";

/**
 * @title HannesExchangeV2Factory
 * @dev 用于部署和管理 HannesExchangeV2Pair 实例的工厂合约
 * @notice 实现了基于角色的访问控制、可升级性和紧急停止功能
 */
contract HannesExchangeV2Factory is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// 角色定义
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    /// PAUSER_ROLE 改为更通用的 OPERATOR_ROLE
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant EXCHANGE_CREATOR_ROLE = keccak256("EXCHANGE_CREATOR_ROLE");

    /// 状态变量
    /// 将单向映射改为双向映射，支持任意ERC20代币对
    mapping(address => mapping(address => address)) public getPair; // token0 => token1 => pair
    address[] public allPairs;

    /// 事件声明
    /// 更新了事件参数以适应ERC20-ERC20交易对
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 pairCount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数
     * @param _admin 管理员地址
     * @param _upgrader 升级角色地址
     * @param _operator 操作者角色地址
     * @param _exchangeCreator 交易对创建者角色地址
     */
    function initialize(
        address _admin,
        address _upgrader,
        address _operator,
        address _exchangeCreator
    ) public initializer {
        require(_admin != address(0), "Admin address cannot be 0");
        require(_upgrader != address(0), "Upgrader address cannot be 0");
        require(_operator != address(0), "Operator address cannot be 0");
        require(_exchangeCreator != address(0), "Exchange creator address cannot be 0");

        /// 初始化基础合约
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        /// 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);
        _grantRole(OPERATOR_ROLE, _operator);
        _grantRole(EXCHANGE_CREATOR_ROLE, _exchangeCreator);
    }

    /**
     * @dev 创建新的交易对
     * @param tokenA 代币A地址
     * @param tokenB 代币B地址
     * @return pair 新创建的交易对地址
     */
    function createPair(
        address tokenA,
        address tokenB
    ) external onlyRole(EXCHANGE_CREATOR_ROLE) whenNotPaused returns (address pair) {
        require(tokenA != tokenB, "HannesExchangeV2Factory: IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "HannesExchangeV2Factory: ZERO_ADDRESS");
        require(getPair[token0][token1] == address(0), "HannesExchangeV2Factory: PAIR_EXISTS");

        /// 部署 HannesExchangeV2Pair 逻辑合约
        HannesExchangeV2Pair pairImpl = new HannesExchangeV2Pair();

        /// 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV2Pair.initialize.selector,
            token0,
            token1
        );

        /// 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(pairImpl), initData);
        pair = address(proxy);

        /// 更新映射
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; /// 反向映射也要更新
        allPairs.push(pair);

        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    /**
     * @dev 获取所有交易对数量
     */
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    /**
     * @dev 紧急暂停
     */
    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    /**
     * @dev 解除暂停
     */
    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
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
     */
    function version() public pure virtual returns (string memory) {
        return "2.0.0";
    }
}