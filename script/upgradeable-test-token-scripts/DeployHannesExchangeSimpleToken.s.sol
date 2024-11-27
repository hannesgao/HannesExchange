// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/upgradeable-test-token/HannesExchangeSimpleToken.sol";
import "forge-std/Script.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户私钥 PRIVATE_KEY_2 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令：
/// forge script script/upgradeable-test-token-scripts/DeployHannesExchangeSimpleToken.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// HannesExchangeSimpleToken 合约地址：0x97C1eeaeB7c648C1ff14F9a40eFfb4ce92be7643

contract DeployHannesExchangeSimpleToken is Script {
    function run() public {
        /// 加载环境变量中的私钥2（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_2）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        address TEST_EOA_ADDRESS_2 = 0xC6A8d2850F326B769bb4e3187621d2B5f18dBFd3;

        /// 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 HannesExchangeTestTokenV1 逻辑合约
        HannesExchangeSimpleToken implementation = new HannesExchangeSimpleToken(TEST_EOA_ADDRESS_2);

        vm.stopBroadcast();

        // 2. 记录部署的合约地址
        console.log(
            "HannesExchangeSimpleToken deployed to:",
            address(implementation)
        );
    }
}
