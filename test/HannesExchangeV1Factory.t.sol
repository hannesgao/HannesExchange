// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "src/HannesExchangeV1Factory.sol";
import "src/HannesExchangeV1Pair.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract HannesExchangeV1FactoryTest is Test {
    HannesExchangeV1Factory public factory;
    HannesExchangeV1Factory public factoryProxy;
    MockERC20 public token;
    
    address public admin;
    address public upgrader;
    address public pauser;
    address public exchangeCreator;
    address public user;

    event ExchangeCreated(
        address indexed tokenAddress,
        address indexed exchangeAddress,
        uint256 exchangeCount
    );

    function setUp() public {
        // 设置测试账户
        admin = makeAddr("admin");
        upgrader = makeAddr("upgrader");
        pauser = makeAddr("pauser");
        exchangeCreator = makeAddr("exchangeCreator");
        user = makeAddr("user");

        // 部署合约
        factory = new HannesExchangeV1Factory();
        
        // 部署代理合约
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV1Factory.initialize.selector,
            admin,
            upgrader,
            pauser,
            exchangeCreator
        );
        
        ERC1967Proxy proxy = new ERC1967Proxy(address(factory), initData);
        factoryProxy = HannesExchangeV1Factory(address(proxy));
        
        // 部署测试代币
        token = new MockERC20();
    }

    function test_Initialize() view public {
        // 验证角色分配是否正确
        assertTrue(factoryProxy.hasRole(factoryProxy.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(factoryProxy.hasRole(factoryProxy.UPGRADER_ROLE(), upgrader));
        assertTrue(factoryProxy.hasRole(factoryProxy.PAUSER_ROLE(), pauser));
        assertTrue(factoryProxy.hasRole(factoryProxy.EXCHANGE_CREATOR_ROLE(), exchangeCreator));
    }

    function testFail_InitializeZeroAddress() public {
        // 测试使用零地址初始化
        factory.initialize(
            address(0),
            upgrader,
            pauser,
            exchangeCreator
        );
    }

    function test_CreateExchange() public {
        vm.startPrank(exchangeCreator);
        
        address exchangeAddress = factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );
        
        vm.stopPrank();

        // 验证映射更新
        assertEq(factoryProxy.tokenToExchange(address(token)), exchangeAddress);
        assertEq(factoryProxy.exchangeToToken(exchangeAddress), address(token));
        assertEq(factoryProxy.idToToken(0), address(token));
        assertEq(factoryProxy.allExchanges(0), exchangeAddress);
        assertEq(factoryProxy.getExchangeCount(), 1);
    }

    function testFail_CreateExchangeUnauthorized() public {
        // 测试未授权用户创建交易对
        vm.prank(user);
        factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );
    }

    function testFail_CreateDuplicateExchange() public {
        // 首次创建交易对
        vm.startPrank(exchangeCreator);
        factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );

        // 尝试为同一代币再次创建交易对
        factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );
        vm.stopPrank();
    }

    function test_GetExchangeInfo() public {
        vm.prank(exchangeCreator);
        address exchangeAddress = factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );

        // 测试各种getter函数
        assertEq(factoryProxy.getExchange(address(token)), exchangeAddress);
        assertEq(factoryProxy.getToken(exchangeAddress), address(token));
        assertEq(factoryProxy.getTokenWithId(0), address(token));
    }

    function test_PauseUnpause() public {
        // 测试暂停功能
        vm.prank(pauser);
        factoryProxy.pause();
        assertTrue(factoryProxy.paused());

        // 测试暂停后无法创建交易对
        vm.prank(exchangeCreator);
        vm.expectRevert();
        factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );

        // 测试解除暂停
        vm.prank(pauser);
        factoryProxy.unpause();
        assertFalse(factoryProxy.paused());

        // 测试解除暂停后可以创建交易对
        vm.prank(exchangeCreator);
        address exchangeAddress = factoryProxy.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );
        assertNotEq(exchangeAddress, address(0));
    }

    function testFail_PauseUnauthorized() public {
        // 测试未授权用户暂停合约
        vm.prank(user);
        factoryProxy.pause();
    }

    function test_Version() view public {
        // 测试版本号
        assertEq(factoryProxy.version(), "1.0.0");
    }
}