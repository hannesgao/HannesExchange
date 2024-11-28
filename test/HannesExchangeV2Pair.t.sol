/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {HannesExchangeV2Pair} from "../src/HannesExchangeV2Pair.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HannesExchangeV2PairTest is Test {
    /// 测试合约
    HannesExchangeV2Pair public implementation;
    HannesExchangeV2Pair public pair;
    ERC20Mock public token0;
    ERC20Mock public token1;

    /// 测试账户
    address public admin = makeAddr("admin");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    /// 测试常量
    uint256 public constant INITIAL_MINT_AMOUNT = 1000000 ether;
    uint256 public constant INITIAL_LIQUIDITY = 1000 ether;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /// 事件
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    function setUp() public {
        vm.startPrank(admin);

        /// 部署模拟代币
        token0 = new ERC20Mock();
        token1 = new ERC20Mock();

        /// 确保token0地址小于token1地址
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        /// 部署实现合约
        implementation = new HannesExchangeV2Pair();
        
        /// 创建初始化调用数据
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV2Pair.initialize.selector,
            address(token0),
            address(token1)
        );

        /// 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        
        /// 创建代理合约的接口
        pair = HannesExchangeV2Pair(address(proxy));

        vm.stopPrank();

        /// 设置测试账户余额
        token0.mint(admin, INITIAL_MINT_AMOUNT);
        token1.mint(admin, INITIAL_MINT_AMOUNT);
        token0.mint(user1, INITIAL_MINT_AMOUNT);
        token1.mint(user1, INITIAL_MINT_AMOUNT);
        token0.mint(user2, INITIAL_MINT_AMOUNT);
        token1.mint(user2, INITIAL_MINT_AMOUNT);

        /// 授权
        vm.startPrank(admin);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user1);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token0.approve(address(pair), type(uint256).max);
        token1.approve(address(pair), type(uint256).max);
        vm.stopPrank();
    }

    /// ===== 初始化测试 =====

    function test_initialization() public view {
        assertEq(address(pair.token0()), address(token0));
        assertEq(address(pair.token1()), address(token1));
        assertEq(pair.reserve0(), 0);
        assertEq(pair.reserve1(), 0);
        assertEq(pair.totalSupply(), 0);
        assertTrue(pair.hasRole(pair.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pair.hasRole(pair.OPERATOR_ROLE(), admin));
        assertTrue(pair.hasRole(pair.UPGRADER_ROLE(), admin));
    }

    function testFail_initialize_zeroAddress() public {
        HannesExchangeV2Pair newImplementation = new HannesExchangeV2Pair();
        
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV2Pair.initialize.selector,
            address(0),
            address(token1)
        );

        new ERC1967Proxy(
            address(newImplementation),
            initData
        );
    }

    function testFail_initialize_sameTokens() public {
        HannesExchangeV2Pair newImplementation = new HannesExchangeV2Pair();
        
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV2Pair.initialize.selector,
            address(token0),
            address(token0)
        );

        new ERC1967Proxy(
            address(newImplementation),
            initData
        );
    }

    /// ===== 添加流动性测试 =====

    function test_addLiquidity_initialLiquidity() public {
        vm.startPrank(admin);
        uint256 liquidity = pair.addLiquidity(
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            admin
        );
        vm.stopPrank();

        /// 验证状态
        assertApproxEqAbs(pair.totalSupply(), liquidity + MINIMUM_LIQUIDITY, 1);
        assertApproxEqAbs(pair.balanceOf(admin), liquidity, 1);
        assertEq(pair.balanceOf(address(1)), MINIMUM_LIQUIDITY);
        assertEq(pair.reserve0(), INITIAL_LIQUIDITY);
        assertEq(pair.reserve1(), INITIAL_LIQUIDITY);
    }

    function test_addLiquidity_subsequentLiquidity() public {
        /// 首次添加流动性
        vm.prank(admin);
        pair.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, admin);

        /// 第二次添加流动性
        vm.prank(user1);
        uint256 liquidity = pair.addLiquidity(
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            user1
        );

        /// 验证状态
        assertApproxEqAbs(
            pair.balanceOf(user1),
            liquidity,
            1,
            "User1 should receive correct LP tokens"
        );
        assertEq(
            pair.reserve0(),
            INITIAL_LIQUIDITY * 2,
            "Reserve0 should be doubled"
        );
        assertEq(
            pair.reserve1(),
            INITIAL_LIQUIDITY * 2,
            "Reserve1 should be doubled"
        );
    }

    /// ===== 移除流动性测试 =====

    function test_removeLiquidity() public {
        /// 首先添加流动性
        vm.startPrank(admin);
        uint256 liquidity = pair.addLiquidity(
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            admin
        );

        /// 移除一半流动性
        (uint256 amount0, uint256 amount1) = pair.removeLiquidity(
            liquidity / 2,
            0,
            0,
            admin
        );
        vm.stopPrank();

        /// 验证返还的代币数量，使用近似比较
        assertApproxEqAbs(
            amount0, 
            INITIAL_LIQUIDITY / 2, 
            1e15, 
            "Should return half of token0"
        );
        assertApproxEqAbs(
            amount1, 
            INITIAL_LIQUIDITY / 2, 
            1e15, 
            "Should return half of token1"
        );

        /// 验证储备量
        assertApproxEqAbs(
            pair.reserve0(), 
            INITIAL_LIQUIDITY / 2, 
            1e15, 
            "Reserve0 should halve"
        );
        assertApproxEqAbs(
            pair.reserve1(), 
            INITIAL_LIQUIDITY / 2, 
            1e15, 
            "Reserve1 should halve"
        );
    }

    /// ===== 交换测试 =====

    function test_swap() public {
        /// 首先添加流动性
        vm.prank(admin);
        pair.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, admin);

        uint256 swapAmount = 1 ether;
        uint256 expectedOutput = pair.getAmountOut(
            swapAmount,
            pair.reserve0(),
            pair.reserve1()
        );

        /// 记录初始余额
        uint256 initialBalance = token1.balanceOf(user1);

        /// 执行交换
        vm.startPrank(user1);
        token0.transfer(address(pair), swapAmount);
        pair.swap(0, expectedOutput, user1);
        vm.stopPrank();

        /// 验证最终余额，使用近似比较
        assertApproxEqAbs(
            token1.balanceOf(user1),
            initialBalance + expectedOutput,
            1e15,
            "Should receive correct amount of token1"
        );
    }

    /// ===== 紧急暂停测试 =====

    function test_pause() public {
        vm.startPrank(admin);
        
        /// 暂停合约
        pair.pause();
        assertTrue(pair.paused(), "Contract should be paused");

        /// 恢复合约
        pair.unpause();
        assertFalse(pair.paused(), "Contract should be unpaused");
        
        vm.stopPrank();
    }

    /// ===== 角色权限测试 =====

    function test_roles() public {
        bytes32 adminRole = pair.DEFAULT_ADMIN_ROLE();
        bytes32 operatorRole = pair.OPERATOR_ROLE();
        bytes32 upgraderRole = pair.UPGRADER_ROLE();

        assertTrue(
            pair.hasRole(adminRole, admin),
            "Admin should have admin role"
        );
        assertTrue(
            pair.hasRole(operatorRole, admin),
            "Admin should have operator role"
        );
        assertTrue(
            pair.hasRole(upgraderRole, admin),
            "Admin should have upgrader role"
        );

        /// 测试非管理员无法暂停
        vm.prank(user1);
        vm.expectRevert();
        pair.pause();
    }

    /// ===== Fuzz测试 =====

    function testFuzz_addLiquidity(uint256 amount0, uint256 amount1) public {
        /// 限制输入范围以避免溢出
        amount0 = bound(amount0, 1000, INITIAL_MINT_AMOUNT);
        amount1 = bound(amount1, 1000, INITIAL_MINT_AMOUNT);

        vm.prank(admin);
        uint256 liquidity = pair.addLiquidity(amount0, amount1, 0, 0, admin);

        assertTrue(liquidity > 0, "Should mint non-zero liquidity");
        assertEq(pair.reserve0(), amount0, "Should update reserve0");
        assertEq(pair.reserve1(), amount1, "Should update reserve1");
    }

    /// ===== 异常情况测试 =====

    function test_preventPriceManipulation() public {
        /// 添加小额流动性
        vm.prank(admin);
        pair.addLiquidity(1 ether, 1 ether, 0, 0, admin);

        /// 尝试通过极小值操纵价格
        vm.startPrank(user1);
        token0.transfer(address(pair), 1);
        vm.expectRevert();
        pair.swap(0, 0.1 ether, user1);
        vm.stopPrank();
    }
}
