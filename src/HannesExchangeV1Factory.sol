// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "./HannesExchangeV1Pair.sol";

/**
 * @title HannesExchangeV1Factory
 * @dev 用于 HannesExchangeV1 的可升级工厂合约，用于部署和管理多个 HannesExchangeV1Pair 实例，以实现多个流动性池（ETH-ERC20 Token Pair）
 * @notice 实现了基于角色的访问控制、可升级性和紧急停止功能
 */
contract HannesExchangeV1Factory is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    /// 角色定义
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EXCHANGE_CREATOR_ROLE =
        keccak256("EXCHANGE_CREATOR_ROLE");

    /// 状态变量
    mapping(address => address) public tokenToExchange;
    mapping(address => address) public exchangeToToken;
    mapping(uint256 => address) public idToToken;
    address[] public allExchanges;

    /// 事件声明
    event ExchangeCreated(
        address indexed tokenAddress,
        address indexed exchangeAddress,
        uint256 exchangeCount
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev 初始化函数，替代构造函数
     * @param _admin 管理员地址
     * @param _upgrader 升级角色地址
     * @param _pauser 暂停角色地址
     * @param _exchangeCreator HannesExchangeV1Pair 创建者角色地址
     */
    function initialize(
        address _admin,
        address _upgrader,
        address _pauser,
        address _exchangeCreator
    ) public initializer {
        require(_admin != address(0), "Admin address cannot be 0");
        require(_upgrader != address(0), "Upgrader address cannot be 0");
        require(_pauser != address(0), "Pauser address cannot be 0");
        require(
            _exchangeCreator != address(0),
            "Exchange creator address cannot be 0"
        );

        /// 初始化基础合约
        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        /// 设置角色
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _upgrader);
        _grantRole(PAUSER_ROLE, _pauser);
        _grantRole(EXCHANGE_CREATOR_ROLE, _exchangeCreator);
    }

    /**
     * @dev 创建新的 HannesExchangeV1Pair 实例
     * @param _tokenAddress 代币地址
     * @param _admin HannesExchangeV1Pair 管理员地址
     * @param _upgrader HannesExchangeV1Pair 升级角色地址
     * @param _pauser HannesExchangeV1Pair 暂停角色地址
     * @notice 只有具有 EXCHANGE_CREATOR_ROLE 的地址可以调用
     * @notice 合约必须未暂停
     */
    function createExchange(
        address _tokenAddress,
        address _admin,
        address _upgrader,
        address _pauser
    ) public onlyRole(EXCHANGE_CREATOR_ROLE) whenNotPaused returns (address) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(
            tokenToExchange[_tokenAddress] == address(0),
            "Exchange already exists"
        );

        /// 部署 HannesExchangeV1Pair 逻辑合约
        HannesExchangeV1Pair exchangeImpl = new HannesExchangeV1Pair();

        /// 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV1Pair.initialize.selector,
            _tokenAddress,
            _admin,
            _upgrader,
            _pauser
        );

        /// 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(exchangeImpl), initData);

        address exchangeAddress = address(proxy);

        /// 更新映射
        tokenToExchange[_tokenAddress] = exchangeAddress;
        exchangeToToken[exchangeAddress] = _tokenAddress;
        idToToken[allExchanges.length] = _tokenAddress;
        allExchanges.push(exchangeAddress);

        emit ExchangeCreated(
            _tokenAddress,
            exchangeAddress,
            allExchanges.length
        );
        return exchangeAddress;
    }

    /**
     * @dev 紧急暂停工厂合约
     * @notice 只有具有 PAUSER_ROLE 的地址可以调用
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev 解除工厂合约暂停
     * @notice 只有具有 PAUSER_ROLE 的地址可以调用
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev 获取指定代币的 HannesExchangeV1Pair 地址
     * @param _tokenAddress 代币地址
     */
    function getExchange(address _tokenAddress) public view returns (address) {
        return tokenToExchange[_tokenAddress];
    }

    /**
     * @dev 获取指定 HannesExchangeV1Pair 的代币地址
     * @param _exchange HannesExchangeV1Pair 地址
     */
    function getToken(address _exchange) public view returns (address) {
        return exchangeToToken[_exchange];
    }

    /**
     * @dev 根据ID获取代币地址
     * @param _tokenId 代币ID
     */
    function getTokenWithId(uint256 _tokenId) public view returns (address) {
        require(_tokenId < allExchanges.length, "Invalid token ID");
        return idToToken[_tokenId];
    }

    /**
     * @dev 获取所有 HannesExchangeV1Pair 数量
     */
    function getExchangeCount() public view returns (uint256) {
        return allExchanges.length;
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
