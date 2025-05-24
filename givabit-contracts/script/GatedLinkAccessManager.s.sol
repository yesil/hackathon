// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {GatedLinkAccessManager} from "../src/GatedLinkAccessManager.sol";
// No longer need to import BitcoinOnAvalanche for deployment here if we are just using an address.

contract GatedLinkAccessManagerScript is Script {
    GatedLinkAccessManager public gatedLinkManager;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // address deployerAddress = vm.addr(deployerPrivateKey); // Not needed if not deploying BTC.B

        address btcBContractAddress = vm.envAddress("BTCB_CONTRACT_ADDRESS");
        require(btcBContractAddress != address(0), "GatedLinkAccessManagerScript: BTCB_CONTRACT_ADDRESS env variable not set or is the zero address.");
        console.log("Using existing BTC.B contract at:", btcBContractAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy GatedLinkAccessManager with the address of the existing BTC.B
        gatedLinkManager = new GatedLinkAccessManager(btcBContractAddress);
        console.log("GatedLinkAccessManager deployed at:", address(gatedLinkManager));

        vm.stopBroadcast();
    }
} 