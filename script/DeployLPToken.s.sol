/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/upgradeable/LPToken.sol";
import "forge-std/Script.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户私钥 PRIVATE_KEY_1 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令：
/// forge script script/DeployLPToken.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// LPToken V1逻辑合约地址: 0x9E27b6d0D0f149dD069AD9f3AC61050F569a5063

contract DeployLPToken is Script {
    function run() public {
        /// 加载环境变量中的私钥1（对应为 deployer 准备的测试用EOA）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_1");

        vm.startBroadcast(deployerPrivateKey);

        /// 部署逻辑合约 LPToken
        LPToken tokenV1 = new LPToken();

        /// 输出逻辑合约地址
        console.log("Token contract address of LPToken V1 (implementation):", address(tokenV1));
        
        vm.stopBroadcast();      
    }
}
