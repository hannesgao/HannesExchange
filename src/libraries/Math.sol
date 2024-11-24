// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Math {
    /**
     * @dev 返回一个无符号整数的平方根
    */
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0; // 0 的平方根是 0

        // 初始值：近似值可以是 x / 2 或 1，使用位运算提高效率
        uint256 z = (x + 1) / 2;
        uint256 y = x;

        // 牛顿迭代法
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    /**
     * @dev 返回两个无符号整数中的最小值
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}