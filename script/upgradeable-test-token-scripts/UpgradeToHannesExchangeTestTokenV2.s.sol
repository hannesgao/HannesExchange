/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/upgradeable-test-token/HannesExchangeTestTokenV2.sol";
import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "openzeppelin-foundry-upgrades/Upgrades.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户的私钥 PRIVATE_KEY_2 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令：
/// forge script script/upgradeable-test-token-scripts/UpgradeToHannesExchangeTestTokenV2.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// HannesExchangeTestTokenV2 逻辑合约地址：0x574921Dcee7DbB56a41c107B1B62Ae020DE6aDAf
/// HannesExchangeTestTokenV2 代理合约地址：0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50

contract UpgradeToHannesExchangeTestTokenV2 is Script {
    function run() public {
        /// 定义 HannesExchangeTestTokenV1 代理合约地址
        address proxy = 0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50;

        /// 加载环境变量中的私钥2（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_2）
        /// 注意：用于升级 HannesExchangeTestTokenV1 合约的EOA账户必须拥有该合约的 UPGRADER_ROLE 角色
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        /// address TEST_EOA_ADDRESS_2 = 0xC6A8d2850F326B769bb4e3187621d2B5f18dBFd3;

        vm.startBroadcast(deployerPrivateKey);

        /// 备注: 在使用 UUPS 模式进行合约升级时，新的逻辑合约地址被添加至代理合约中
        /// 而代理合约的存储不会被重置，所以代理合约中原有的逻辑合约的状态变量值依然有效
        /// 也包括 Initializable 的初始化状态和 AccessControlUpgradeable 的访问控制角色设置
        /// 因此在进行合约升级时无需再次调用 initialize() 函数

        /// 特殊情况: 新的逻辑合约引入了新的状态变量，或者需要额外的初始化逻辑
        /// 此时可以定义一个新的初始化函数，例如 reinitialize() 并使用 reinitializer 修饰符
        /// reinitializer 修饰符允许在已经完成一次初始化后再次调用初始化逻辑，但只会执行一次
        /// 相关文档: https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable

        /// 升级 HannesExchangeTestTokenV1 代理合约为 HannesExchangeTestTokenV2 代理合约
        /// 使用 openzeppelin-foundry-upgrades 插件提供的 upgradeProxy() 方法，简化操作
        /// 相关文档: https://docs.openzeppelin.com/upgrades-plugins/1.x/foundry-upgrades#upgrade_a_proxy_or_beacon
        Upgrades.upgradeProxy(
            proxy,
            "HannesExchangeTestTokenV2.sol:HannesExchangeTestTokenV2",
            ""
        );

        /// 输出代理合约地址
        console.log(
            "HannesExchangeTestTokenV2-Proxy deployed to:",
            address(proxy)
        );

        vm.stopBroadcast();
    }
}
