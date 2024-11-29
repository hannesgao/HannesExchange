// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/HannesExchangeV1Factory.sol";
import "src/HannesExchangeV1Pair.sol";
import "forge-std/Script.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户私钥 PRIVATE_KEY_1 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 注意：
/// 本部署脚本仅做测试之用，流动性池合约的部署原则上需要由工厂合约来管理

/// 部署命令：
/// forge script script/DeployHannesExchangeV1Pair.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// HannesExchangeV1Factory 逻辑合约地址：0x4861517289ed9b9a837cAD1433c41DC3C5eF7494
/// HannesExchangeV1Factory 代理合约地址：0xCE93b8542a1F6fF1A60C22Ed4666118512faD696

/// 部署流动性池所需的，已部署好的，可用于测试用的ERC20代币合约地址：
/// Hannes Exchange Simple Token (HEST) 合约地址：0x97C1eeaeB7c648C1ff14F9a40eFfb4ce92be7643
/// Hannes Exchange Test TokenV2 (HETTV2) 代理合约地址：0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50

contract DeployHannesExchangeV1Pair is Script {
    function run() external {
        /// 加载环境变量中的私钥1（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_1）
        /// 注意：用于部署 DeployHannesExchangeV1Pair 合约的EOA账户必须拥有工厂合约的 EXCHANGE_CREATOR_ROLE 角色
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_1");
        address TEST_EOA_ADDRESS_1 = 0x7f7DC44Bcc734C9215cE2C54268fbed96cd10FEE;

        /// 指定已经部署好的 HannesExchangeV1Factory 代理合约地址
        address factoryProxy = 0xCE93b8542a1F6fF1A60C22Ed4666118512faD696;
        
        /// 指定要创建流动性池的ERC20代币地址
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");  /// 占位符，请替换为实际的ERC20代币地址
        
        /// 设置各个访问控制角色的地址，为简化测试部署，皆设置为 TEST_EOA_ADDRESS_1
        /// 可根据部署和访问控制需求修改为不同的EOA账户
        address pairAdmin = TEST_EOA_ADDRESS_1;
        address pairUpgrader = TEST_EOA_ADDRESS_1;
        address pairPauser = TEST_EOA_ADDRESS_1;
        
        /// 开始广播交易
        vm.startBroadcast(deployerPrivateKey);
        
        /// 1. 获取 HannesExchangeV1Factory 合约实例
        HannesExchangeV1Factory factory = HannesExchangeV1Factory(factoryProxy);
        
        /// 2. 部署 DeployHannesExchangeV1Pair 逻辑合约
        HannesExchangeV1Pair pair = new HannesExchangeV1Pair();
        
        /// 3. 通过 HannesExchangeV1Factory 部署 DeployHannesExchangeV1Pair 代理合约
        address pairProxy = factory.createExchange(
            tokenAddress,
            pairAdmin,
            pairUpgrader,
            pairPauser
        );
        
        console.log("Pair Implementation deployed to:", address(pair));
        console.log("DeployHannesExchangeV1Pair-Pair Proxy deployed to:", pairProxy);
        
        vm.stopBroadcast();
    }
}