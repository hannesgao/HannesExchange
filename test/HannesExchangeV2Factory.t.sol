/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HannesExchangeV2Factory} from "../src/HannesExchangeV2Factory.sol";
import {HannesExchangeV2Pair} from "../src/HannesExchangeV2Pair.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HannesExchangeV2FactoryTest is Test {
    HannesExchangeV2Factory public factory;
    HannesExchangeV2Factory public factoryProxy;
    ERC20Mock public tokenA;
    ERC20Mock public tokenB;
    ERC20Mock public tokenC;

    address public admin;
    address public upgrader;
    address public operator;
    address public exchangeCreator;
    address public user;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant EXCHANGE_CREATOR_ROLE =
        keccak256("EXCHANGE_CREATOR_ROLE");

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256 pairCount
    );

    function setUp() public {
        /// 设置账户
        admin = makeAddr("admin");
        upgrader = makeAddr("upgrader");
        operator = makeAddr("operator");
        exchangeCreator = makeAddr("exchangeCreator");
        user = makeAddr("user");

        /// 部署代币合约
        tokenA = new ERC20Mock();
        tokenB = new ERC20Mock();
        tokenC = new ERC20Mock();

        /// 部署工厂合约
        factory = new HannesExchangeV2Factory();
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV2Factory.initialize.selector,
            admin,
            upgrader,
            operator,
            exchangeCreator
        );
        /// 部署代理合约
        factoryProxy = HannesExchangeV2Factory(
            deployProxy(address(factory), initData)
        );
    }

    /// ======== 初始化测试 ========

    function test_initialization() public view {
        /// 验证角色分配
        assertTrue(
            factoryProxy.hasRole(factoryProxy.DEFAULT_ADMIN_ROLE(), admin)
        );
        assertTrue(factoryProxy.hasRole(UPGRADER_ROLE, upgrader));
        assertTrue(factoryProxy.hasRole(OPERATOR_ROLE, operator));
        assertTrue(
            factoryProxy.hasRole(EXCHANGE_CREATOR_ROLE, exchangeCreator)
        );

        /// 验证初始状态
        assertEq(factoryProxy.allPairsLength(), 0);
        assertFalse(factoryProxy.paused());
    }

    function testFail_reinitialize() public {
        /// 尝试重新初始化应该失败
        factoryProxy.initialize(admin, upgrader, operator, exchangeCreator);
    }

    function testFail_initializeWithZeroAddress() public {
        HannesExchangeV2Factory newFactory = new HannesExchangeV2Factory();
        newFactory.initialize(address(0), upgrader, operator, exchangeCreator);
    }

    /// ======== 创建交易对测试 ========

    function test_createPair() public {
        vm.startPrank(exchangeCreator);

        /// 记录创建前的状态
        uint256 pairCountBefore = factoryProxy.allPairsLength();

        /// 创建交易对
        address pair = factoryProxy.createPair(
            address(tokenA),
            address(tokenB)
        );

        /// 验证交易对创建结果
        assertEq(factoryProxy.allPairsLength(), pairCountBefore + 1);
        assertEq(factoryProxy.getPair(address(tokenA), address(tokenB)), pair);
        assertEq(factoryProxy.getPair(address(tokenB), address(tokenA)), pair);
        assertEq(factoryProxy.allPairs(pairCountBefore), pair);

        vm.stopPrank();
    }

    function test_createMultiplePairs() public {
        vm.startPrank(exchangeCreator);

        /// 创建多个交易对
        address pair1 = factoryProxy.createPair(
            address(tokenA),
            address(tokenB)
        );
        address pair2 = factoryProxy.createPair(
            address(tokenB),
            address(tokenC)
        );
        address pair3 = factoryProxy.createPair(
            address(tokenA),
            address(tokenC)
        );

        /// 验证结果
        assertEq(factoryProxy.allPairsLength(), 3);
        assertTrue(pair1 != pair2 && pair2 != pair3 && pair1 != pair3);
        assertEq(factoryProxy.getPair(address(tokenA), address(tokenB)), pair1);
        assertEq(factoryProxy.getPair(address(tokenB), address(tokenC)), pair2);
        assertEq(factoryProxy.getPair(address(tokenA), address(tokenC)), pair3);

        vm.stopPrank();
    }

    function testFail_createPairWithSameTokens() public {
        vm.prank(exchangeCreator);
        factoryProxy.createPair(address(tokenA), address(tokenA));
    }

    function testFail_createPairWithZeroAddress() public {
        vm.prank(exchangeCreator);
        factoryProxy.createPair(address(0), address(tokenA));
    }

    function testFail_createExistingPair() public {
        vm.startPrank(exchangeCreator);
        factoryProxy.createPair(address(tokenA), address(tokenB));
        factoryProxy.createPair(address(tokenA), address(tokenB));
        vm.stopPrank();
    }

    function testFail_createPairWithoutRole() public {
        vm.prank(user);
        factoryProxy.createPair(address(tokenA), address(tokenB));
    }

    /// ======== 暂停功能测试 ========

    function test_pause() public {
        /// 使用operator账户暂停合约
        vm.prank(operator);
        factoryProxy.pause();
        vm.stopPrank();

        /// 验证暂停状态
        assertTrue(factoryProxy.paused());

        /// 验证暂停后无法创建交易对
        vm.expectRevert();
        vm.prank(exchangeCreator);
        factoryProxy.createPair(address(tokenA), address(tokenB));
        vm.stopPrank();
    }

    function test_unpause() public {
        /// 先暂停
        vm.prank(operator);
        factoryProxy.pause();

        /// 再解除暂停
        vm.prank(operator);
        factoryProxy.unpause();

        /// 验证可以继续创建交易对
        vm.prank(exchangeCreator);
        address pair = factoryProxy.createPair(
            address(tokenA),
            address(tokenB)
        );
        assertTrue(pair != address(0));
    }

    function testFail_pauseWithoutRole() public {
        vm.prank(user);
        factoryProxy.pause();
    }

    function testFail_unpauseWithoutRole() public {
        vm.prank(operator);
        factoryProxy.pause();

        vm.prank(user);
        factoryProxy.unpause();
    }

    /// ======== 升级测试 ========

    function test_upgrade() public {
        /// 部署新版本合约
        HannesExchangeV2Factory newImplementation = new HannesExchangeV2Factory();

        /// 使用upgrader账户进行升级
        vm.prank(upgrader);
        HannesExchangeV2Factory(address(factoryProxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );

        /// 验证版本号
        assertEq(factoryProxy.version(), "2.0.0");
    }

    function testFail_upgradeWithoutRole() public {
        HannesExchangeV2Factory newImplementation = new HannesExchangeV2Factory();

        vm.prank(user);
        HannesExchangeV2Factory(address(factoryProxy)).upgradeToAndCall(
            address(newImplementation),
            ""
        );
    }

    /// ======== 内部工具函数 ========

    function deployProxy(
        address implementation,
        bytes memory initData
    ) internal returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(ERC1967Proxy).creationCode,
            abi.encode(implementation, initData)
        );
        address proxy;
        assembly {
            proxy := create(0, add(bytecode, 32), mload(bytecode))
        }
        return proxy;
    }
}
