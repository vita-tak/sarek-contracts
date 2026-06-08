// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MMRVerifier} from "../src/MMRVerifier.sol";

contract DeployMMRVerifier is Script {
    function run() external {
        address hashStampAddress = vm.envAddress("SEPOLIA_CONTRACT_ADDRESS");

        vm.startBroadcast();
        MMRVerifier verifier = new MMRVerifier(hashStampAddress);
        console.log("MMRVerifier deployed to:", address(verifier));
        vm.stopBroadcast();
    }
}