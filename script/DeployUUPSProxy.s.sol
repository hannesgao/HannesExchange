/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../src/upgradeable/LPToken.sol";
import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户的私钥 PRIVATE_KEY_1 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令：
/// forge script script/DeployUUPSProxy.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// LPToken V1逻辑合约地址: 0x9E27b6d0D0f149dD069AD9f3AC61050F569a5063
/// UUPS代理合约地址: 0x956EAF8F00e3f1D30881e9EF91d93A09C5013dF4

contract DeployUUPSProxy is Script {
    function run() public {
        /// 定义发起合约部署的EOA账户地址
        address deployer = 0x7f7DC44Bcc734C9215cE2C54268fbed96cd10FEE;

        /// 定义有权限调用 mint() 函数的EOA账户地址
        address minter = 0x7f7DC44Bcc734C9215cE2C54268fbed96cd10FEE;
        
        /// 定义有权限发起合约升级的EOA账户地址
        address upgrader = 0xC6A8d2850F326B769bb4e3187621d2B5f18dBFd3;

        /// 加载环境变量中的私钥1（对应发起合约部署的EOA账户地址）作为 msg.sender
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_1");

        vm.startBroadcast(deployerPrivateKey);

        /// LPToken V1 合约在 Sepolia Testnet 上的合约地址
        address tokenV1 = 0x9E27b6d0D0f149dD069AD9f3AC61050F569a5063;

        /// 将逻辑合约的 initializer() 函数的三个参数编码进部署代理合约时的 calldata
        bytes memory data = abi.encodeWithSelector(
            LPToken.initialize.selector,
            deployer,
            minter,
            upgrader
        );

        /// 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(tokenV1, data);

        /// 输出逻辑合约地址和代理合约地址
        console.log("Logic Contract:", address(tokenV1));
        console.log("Proxy Address:", address(proxy));

        vm.stopBroadcast();
    }
}

