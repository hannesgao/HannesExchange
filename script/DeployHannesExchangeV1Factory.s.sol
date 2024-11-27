/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/HannesExchangeV1Factory.sol";
import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户私钥 PRIVATE_KEY_1 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令：
/// forge script script/DeployHannesExchangeV1Factory.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// HannesExchangeV1Factory 逻辑合约地址：0x4861517289ed9b9a837cAD1433c41DC3C5eF7494
/// HannesExchangeV1Factory 代理合约地址：0xCE93b8542a1F6fF1A60C22Ed4666118512faD696

contract DeployHannesExchangeV1Factory is Script {
    function run() external {
        /// 加载环境变量中的私钥1（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_1）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_1");
        address TEST_EOA_ADDRESS_1 = 0x7f7DC44Bcc734C9215cE2C54268fbed96cd10FEE;
        
        /// 设置各个访问控制角色的地址，为简化测试部署，皆设置为 TEST_EOA_ADDRESS_1
        /// 可根据部署和访问控制需求修改为不同的EOA账户
        address admin = TEST_EOA_ADDRESS_1;
        address upgrader = TEST_EOA_ADDRESS_1;
        address pauser = TEST_EOA_ADDRESS_1;
        address exchangeCreator = TEST_EOA_ADDRESS_1;
        
        /// 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        /// 1. 部署 HannesExchangeV1Factory 逻辑合约
        HannesExchangeV1Factory factory = new HannesExchangeV1Factory();
        
        /// 2. 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeV1Factory.initialize.selector,
            admin,
            upgrader,
            pauser,
            exchangeCreator
        );
        
        /// 3. 部署 HannesExchangeV1Factory 代理合约
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factory),
            initData
        );
        
        /// 4. 记录部署的合约地址
        console.log("HannesExchangeV1Factory-Implementation deployed to:", address(factory));
        console.log("HannesExchangeV1Factory-Proxy deployed to:", address(factoryProxy));
        
        vm.stopBroadcast();
    }
}