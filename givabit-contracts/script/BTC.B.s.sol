// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BitcoinOnAvalanche} from "../src/BTC.B.sol";

contract BTCBScript is Script {
    BitcoinOnAvalanche public btcB;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // The BitcoinOnAvalanche constructor requires a recipient and an initialOwner.
        // Using the deployer's address for both.
        btcB = new BitcoinOnAvalanche(deployerAddress, deployerAddress);

        console.log("BTC.B deployed at:", address(btcB));

        vm.stopBroadcast();
    }
}
