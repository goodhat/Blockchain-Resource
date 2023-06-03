// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../contracts/SimpleSwap.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast(bytes32(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));
        address token0 = makeAddr("token0");
        address token1 = makeAddr("token1");
        SimpleSwap simpleswap = new SimpleSwap(token0, token1);

        vm.stopBroadcast();
    }
}
