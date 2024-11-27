// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract HannesExchangeSimpleToken is ERC20, ERC20Permit, Ownable {
    constructor(address initialOwner)
        ERC20("Hannes Exchange Simple Token", "HEST")
        ERC20Permit("Hannes Exchange Simple Token")
        Ownable(initialOwner)
        
    {
        // 初始供应量为100万枚
        _mint(msg.sender, 1000000 ether);
    }
}