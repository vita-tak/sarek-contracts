// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {HashStamp} from "../src/HashStamp.sol";

contract DeployHashStamp is Script {
    function run() external {
        vm.startBroadcast();

        HashStamp hashStamp = new HashStamp();
        console.log("HashStamp deployed to:", address(hashStamp));

        vm.stopBroadcast();
    }
}