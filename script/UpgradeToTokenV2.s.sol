// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LPTokenV2} from "../src/upgradeable/LPTokenV2.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeToTokenV2 is Script {
    function run() public {
        /// 定义UUPS代理合约地址
        address proxy = 0x956EAF8F00e3f1D30881e9EF91d93A09C5013dF4;

        /// 定义有权限发起合约升级的EOA账户地址
        address upgrader = 0xC6A8d2850F326B769bb4e3187621d2B5f18dBFd3;

        // 加载环境变量中的私钥2（对应有权限发起合约升级的EOA账户地址）作为 msg.sender
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");

        vm.startBroadcast(deployerPrivateKey);

        /// 部署新的逻辑合约 LPTokenV2
        LPTokenV2 tokenV2 = new LPTokenV2();

        /// 将新的逻辑合约的 initializer() 函数的三个参数编码进部署代理合约时的 calldata
        /// bytes memory data = abi.encodeCall(LPTokenV2.initialize, (admin, minter, upgrader));

        /// 备注: 在使用 UUPS 模式进行合约升级时，新的逻辑合约地址被添加至代理合约中
        /// 而代理合约的存储不会被重置，所以代理合约中原有的逻辑合约的状态变量值依然有效
        /// 也包括 Initializable 的初始化状态和 AccessControlUpgradeable 的访问控制角色设置
        /// 因此在进行合约升级时无需再次调用 initialize() 函数
 
        /// 特殊情况: 新的逻辑合约引入了新的状态变量，或者需要额外的初始化逻辑
        /// 此时可以定义一个新的初始化函数，例如 reinitialize() 并使用 reinitializer 修饰符
        /// reinitializer 修饰符允许在已经完成一次初始化后再次调用初始化逻辑，但只会执行一次
        /// 相关文档: https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable

        /// 升级代理合约
        /// 使用 openzeppelin-foundry-upgrades 插件提供的 upgradeProxy() 方法，简化操作
        /// 相关文档: https://docs.openzeppelin.com/upgrades-plugins/1.x/foundry-upgrades#upgrade_a_proxy_or_beacon
        Upgrades.upgradeProxy(proxy, "LPTokenV2.sol:LPTokenV2", "", upgrader);

        /// 输出新的逻辑合约地址
        console.log("New Logic Contract:", address(tokenV2));
        /// 输出代理合约地址
        console.log("Proxy Address:", address(proxy));

        vm.stopBroadcast();
    }
}

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户的私钥 PRIVATE_KEY_1 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令: forge script script/UpgradeToTokenV2.s.sol --rpc-url sepolia --broadcast --verify

/// LPToken V1逻辑合约地址: 0x9E27b6d0D0f149dD069AD9f3AC61050F569a5063
/// LPToken V2逻辑合约地址：0x15ebF5c909153E906698b23FfB5b80889af1b546
/// UUPS代理合约地址: 0x956EAF8F00e3f1D30881e9EF91d93A09C5013dF4
