/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {HannesExchangeV2Factory} from "../src/HannesExchangeV2Factory.sol";
import {HannesExchangeV2Pair} from "../src/HannesExchangeV2Pair.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// 部署注意事项：
/// 部署前请按需修改该脚本参数中的各种EOA以及合约账户地址
/// 部署前需在 .env 以及 foundry.toml 中设置部署用测试EOA账户私钥 PRIVATE_KEY_2 和EtherScan的API秘钥 ETHERSCAN_API_KEY
/// 部署前请一定确认 .gitignore 中有 .env 文件，以确保私钥和API秘钥不被同步至远程仓库

/// 注意：
/// 本部署脚本仅做测试之用，流动性池合约的部署原则上需要由工厂合约来管理

/// 部署命令：
/// forge script script/DeployHannesExchangeV2.s.sol:DeployHannesExchangeV2 --rpc-url sepolia --broadcast --verify
/// forge script script/DeployHannesExchangeV2.s.sol:CreatePairV2 --rpc-url sepolia --broadcast --verify

/// 合约地址：
/// HannesExchangeV2Factory 逻辑合约地址：0x06a989e8CF282Df370580c0eBCD9ea21d63D1416
/// HannesExchangeV2Factory 代理合约地址：0x584759bd410D473d3f455AA478055961632eac61
/// 实现 HEST - HETTV2 代币对的 HannesExchangeV2Pair 逻辑合约地址：0xb1e380944ce43366d34e6df667bda013d777c783
/// 实现 HEST - HETTV2 代币对的 HannesExchangeV2Pair 代理合约地址：0x80b8C699F7Ae4D72Dd3C366CbA2f9A491C666fC8

/// 部署流动性池所需的，已部署好的，可用于测试用的ERC20代币合约地址：
/// Hannes Exchange Simple Token (HEST) 合约地址：0x97C1eeaeB7c648C1ff14F9a40eFfb4ce92be7643
/// Hannes Exchange Test TokenV2 (HETTV2) 代理合约地址：0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50

/**
 * @title DeployHannesExchangeV2
 * @dev 部署 HannesExchangeV2Factory 和 HannesExchangeV2Pair 合约的脚本
 */
contract DeployHannesExchangeV2 is Script {
    function run() public {
        /// 加载环境变量中的私钥2（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_2）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        address TEST_EOA_ADDRESS_2 = 0xC6A8d2850F326B769bb4e3187621d2B5f18dBFd3;

        /// 开始广播交易
        vm.startBroadcast(deployerPrivateKey);

        /// 1. 部署Factory逻辑合约
        HannesExchangeV2Factory factory = new HannesExchangeV2Factory();
        console.log("Factory Logic Contract deployed at:", address(factory));

        /// 2. 准备Factory初始化数据
        /// 设置各个访问控制角色的地址，为简化测试部署，皆设置为 TEST_EOA_ADDRESS_2
        /// 可根据部署和访问控制需求修改为不同的EOA账户
        bytes memory factoryInitData = abi.encodeWithSelector(
            HannesExchangeV2Factory.initialize.selector,
            TEST_EOA_ADDRESS_2, /// 管理员地址
            TEST_EOA_ADDRESS_2, /// 升级角色地址
            TEST_EOA_ADDRESS_2, /// 操作者角色地址
            TEST_EOA_ADDRESS_2 /// 交易对创建者角色地址
        );

        /// 3. 部署Factory代理合约
        ERC1967Proxy factoryProxy = new ERC1967Proxy(
            address(factory),
            factoryInitData
        );
        console.log(
            "Factory Proxy Contract deployed at:",
            address(factoryProxy)
        );

        /// 4. 为了便于使用，将代理合约转换为Factory接口
        HannesExchangeV2Factory factoryInstance = HannesExchangeV2Factory(
            address(factoryProxy)
        );

        /// 部署完成后进行基本验证
        require(
            factoryInstance.hasRole(
                factoryInstance.DEFAULT_ADMIN_ROLE(),
                TEST_EOA_ADDRESS_2
            ),
            "Admin role not set correctly"
        );
        require(
            factoryInstance.hasRole(
                factoryInstance.UPGRADER_ROLE(),
                TEST_EOA_ADDRESS_2
            ),
            "Upgrader role not set correctly"
        );
        require(
            factoryInstance.hasRole(
                factoryInstance.OPERATOR_ROLE(),
                TEST_EOA_ADDRESS_2
            ),
            "Operator role not set correctly"
        );
        require(
            factoryInstance.hasRole(
                factoryInstance.EXCHANGE_CREATOR_ROLE(),
                TEST_EOA_ADDRESS_2
            ),
            "Exchange creator role not set correctly"
        );

        console.log("All roles set correctly");
        console.log("Factory contract version:", factoryInstance.version());

        vm.stopBroadcast();
    }
}

/**
 * @title DeployTestTokensAndCreatePair
 * @dev 部署测试代币并创建交易对的脚本
 */
contract CreatePairV2 is Script {
    function run() public {
        /// 加载环境变量中的私钥2（对应为 deployer 准备的测试用EOA，即下方的 TEST_EOA_ADDRESS_2）
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_2");
        vm.startBroadcast(deployerPrivateKey);

        /// 1. 假设我们已经有Factory代理合约地址（从之前的部署中获取）
        address factoryProxyAddress = 0x584759bd410D473d3f455AA478055961632eac61;
        HannesExchangeV2Factory factory = HannesExchangeV2Factory(
            factoryProxyAddress
        );

        /// 2. 部署两个测试ERC20代币（下一步需要已经部署好的测试代币合约地址）
        /// TestToken token0 = new TestToken("Test Token 0", "TT0");
        /// TestToken token1 = new TestToken("Test Token 1", "TT1");

        /// 部署流动性池所需的，已部署好的，可用于测试用的ERC20代币合约地址：
        /// Hannes Exchange Simple Token (HEST) 合约地址：0x97C1eeaeB7c648C1ff14F9a40eFfb4ce92be7643
        /// Hannes Exchange Test TokenV2 (HETTV2) 代理合约地址：0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50

        /// 这里使用预设的代币地址进行测试
        address token0 = 0x97C1eeaeB7c648C1ff14F9a40eFfb4ce92be7643;
        address token1 = 0xb711c0fA82D2ed7814282c83AE15B6F944DD2b50;

        console.log("Token0 address:", token0);
        console.log("Token1 address:", token1);

        /// 3. 通过Factory创建交易对
        /// 注意：调用者需要有EXCHANGE_CREATOR_ROLE权限
        address pairAddress = factory.createPair(token0, token1);
        console.log("Pair contract deployed at:", pairAddress);

        /// 4. 验证交易对创建是否成功
        require(
            factory.getPair(token0, token1) == pairAddress,
            "Pair not created correctly"
        );
        require(
            factory.getPair(token1, token0) == pairAddress,
            "Reverse pair mapping not set"
        );

        console.log("Pair creation verified successfully");
        console.log("Total pairs:", factory.allPairsLength());

        vm.stopBroadcast();
    }
}
