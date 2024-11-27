// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "src/HannesExchangeV1Factory.sol";
import "src/HannesExchangeV1Pair.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// 模拟ERC20代币合约
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract HannesExchangeV1PairTest is Test {
    HannesExchangeV1Factory factory;
    HannesExchangeV1Pair pair;
    MockToken token;
    
    address admin = address(1);
    address upgrader = address(2);
    address pauser = address(3);
    address exchangeCreator = address(4);
    address user1 = address(5);
    address user2 = address(6);
    
    // 设置初始余额
    uint256 constant INITIAL_ETH_BALANCE = 100 ether;
    uint256 constant INITIAL_TOKEN_BALANCE = 1000000 * 10**18;

    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event TokenPurchased(address indexed buyer, uint256 ethAmount, uint256 tokensReceived);
    event TokenSold(address indexed seller, uint256 tokensSold, uint256 ethReceived);

    function setUp() public {
        // 部署工厂合约
        factory = new HannesExchangeV1Factory();
        
        // 部署代理合约并初始化工厂
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV1Factory.initialize.selector,
            admin,
            upgrader,
            pauser,
            exchangeCreator
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(factory), initData);
        factory = HannesExchangeV1Factory(address(proxy));
        
        // 部署代币合约
        token = new MockToken();
        
        // 设置用户初始余额
        vm.deal(user1, INITIAL_ETH_BALANCE);
        vm.deal(user2, INITIAL_ETH_BALANCE);
        token.transfer(user1, INITIAL_TOKEN_BALANCE / 2);
        token.transfer(user2, INITIAL_TOKEN_BALANCE / 2);
        
        // 创建交易对
        vm.prank(exchangeCreator);
        address pairAddress = factory.createExchange(
            address(token),
            admin,
            upgrader,
            pauser
        );
        pair = HannesExchangeV1Pair(pairAddress);
    }

    function test_InitialState() view public {
        assertEq(pair.tokenAddress(), address(token));
        assertEq(pair.factoryAddress(), address(factory));
        assertTrue(pair.hasRole(pair.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(pair.hasRole(pair.UPGRADER_ROLE(), upgrader));
        assertTrue(pair.hasRole(pair.PAUSER_ROLE(), pauser));
    }

    function test_AddInitialLiquidity() public {
        uint256 ethAmount = 10 ether;
        uint256 tokenAmount = 1000 * 10**18;
        
        vm.startPrank(user1);
        token.approve(address(pair), tokenAmount);
        
        vm.expectEmit(true, false, false, true);
        emit LiquidityAdded(user1, ethAmount, tokenAmount);
        
        uint256 liquidity = pair.addLiquidity{value: ethAmount}(tokenAmount);
        vm.stopPrank();
        
        assertEq(liquidity, ethAmount);
        assertEq(pair.balanceOf(user1), ethAmount);
        assertEq(pair.getTokenReserves(), tokenAmount);
        assertEq(address(pair).balance, ethAmount);
    }

    function test_RemoveLiquidity() public {
        // 首先添加流动性
        vm.startPrank(user1);
        token.approve(address(pair), 1000 * 10**18);
        uint256 liquidity = pair.addLiquidity{value: 10 ether}(1000 * 10**18);
        
        vm.expectEmit(true, false, false, true);
        emit LiquidityRemoved(user1, 10 ether, 1000 * 10**18);
        
        (uint256 ethAmount, uint256 tokenAmount) = pair.removeLiquidity(liquidity);
        vm.stopPrank();
        
        assertEq(ethAmount, 10 ether);
        assertEq(tokenAmount, 1000 * 10**18);
        assertEq(pair.totalSupply(), 0);
    }

function test_SwapEthForTokens() public {
    // 添加初始流动性
    uint256 initialEth = 100 ether;
    uint256 initialTokens = 100000 * 10**18;
    
    vm.startPrank(user1);
    token.approve(address(pair), initialTokens);
    pair.addLiquidity{value: initialEth}(initialTokens);
    vm.stopPrank();
    
    // 准备交易参数
    uint256 ethToSwap = 50 ether;
    
    // 在交易前获取预期输出
    uint256 expectedTokenOutput = pair.getTokenAmount(ethToSwap);
    
    // 设置较低的最小输出要求（预期输出的99%）
    uint256 minTokens = (expectedTokenOutput * 99) / 100;
    
    uint256 initialTokenBalance = token.balanceOf(user2);
    
    vm.startPrank(user2);
    uint256 tokenOutput = pair.swapEthForTokens{value: ethToSwap}(
        minTokens,
        user2
    );
    vm.stopPrank();
    
    // 验证输出
    assertGe(tokenOutput, minTokens, "Received tokens less than minimum");
    assertLe(tokenOutput, expectedTokenOutput, "Received tokens more than expected");
    
    // 验证余额变化
    assertEq(
        token.balanceOf(user2) - initialTokenBalance,
        tokenOutput,
        "Token balance change incorrect"
    );
    
    // 打印实际值以便调试
    console.log("Expected output:", expectedTokenOutput);
    console.log("Actual output:", tokenOutput);
    console.log("Minimum required:", minTokens);
}

    function test_SwapTokensForEth() public {
        // 添加初始流动性
        vm.startPrank(user1);
        token.approve(address(pair), 1000 * 10**18);
        pair.addLiquidity{value: 10 ether}(1000 * 10**18);
        vm.stopPrank();
        
        uint256 tokenAmount = 500 * 10**18;
        uint256 expectedEthOutput = pair.getEthAmount(tokenAmount);
        
        vm.startPrank(user2);
        token.approve(address(pair), tokenAmount);
        
        uint256 ethOutput = pair.swapTokenForEth(tokenAmount, expectedEthOutput);
        vm.stopPrank();
        
        assertEq(ethOutput, expectedEthOutput);
    }

    function test_PauseAndUnpause() public {
        vm.startPrank(pauser);
        pair.pause();
        assertTrue(pair.paused());
        
        vm.expectRevert();
        vm.startPrank(user1);
        pair.addLiquidity{value: 1 ether}(100 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(pauser);
        pair.unpause();
        assertFalse(pair.paused());
    }

    function test_RevertWhen_InsufficientLiquidity() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid values provided");
        pair.addLiquidity{value: 0}(0);
        vm.stopPrank();
    }
}