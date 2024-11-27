// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "src/upgradeable-test-token/HannesExchangeTestTokenV1.sol";
import "src/upgradeable-test-token/HannesExchangeTestTokenV2.sol";
import "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户私钥 PRIVATE_KEY_2 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 部署命令：
/// forge script script/upgradeable-test-token-scripts/DeployHannesExchangeTestTokenV1.s.sol --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// HannesExchangeTestTokenV1 逻辑合约地址：0xA0216C3a9AA8A9619215B5969289526c363Fa30b
/// HannesExchangeTestTokenV1 代理合约地址：0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50

contract DeployHannesExchangeTestTokenV1 is Script {
    function run() public {
        /// 加载环境变量中的私钥2（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_2）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        address TEST_EOA_ADDRESS_2 = 0xC6A8d2850F326B769bb4e3187621d2B5f18dBFd3;

        /// 设置各个访问控制角色的地址，为简化测试部署，皆设置为 TEST_EOA_ADDRESS_2
        /// 可根据部署和访问控制需求修改为不同的EOA账户
        address defaultAdmin = TEST_EOA_ADDRESS_2;
        address minter = TEST_EOA_ADDRESS_2;
        address upgrader = TEST_EOA_ADDRESS_2;

        /// 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        // 1. 部署 HannesExchangeTestTokenV1 逻辑合约
        HannesExchangeTestTokenV1 implementationV1 = new HannesExchangeTestTokenV1();

        // 2. 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            HannesExchangeTestTokenV1.initialize.selector,
            defaultAdmin,
            minter,
            upgrader
        );

        // 3. 部署 HannesExchangeTestTokenV1 代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementationV1),
            initData
        );

        vm.stopBroadcast();

        // 4. 记录部署的合约地址
        console.log(
            "HannesExchangeTestTokenV1-Implementation deployed to:",
            address(implementationV1)
        );
        console.log(
            "HannesExchangeTestTokenV1-Proxy deployed to:",
            address(proxy)
        );
    }
}
