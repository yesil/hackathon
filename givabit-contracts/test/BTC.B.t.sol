// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {BitcoinOnAvalanche} from "../src/BTC.B.sol";

contract BTCBTest is Test {
    BitcoinOnAvalanche public btcB;
    address public owner = address(0x1);
    address public recipient = address(0x2);

    function setUp() public {
        btcB = new BitcoinOnAvalanche(recipient, owner);
    }

    function test_NameAndSymbol() public view {
        assertEq(btcB.name(), "Bitcoin on Avalanche");
        assertEq(btcB.symbol(), "BTC.B");
    }

    function test_InitialSupply() public view {
        assertEq(btcB.totalSupply(), 1000000 * 10 ** btcB.decimals());
        assertEq(btcB.balanceOf(recipient), 1000000 * 10 ** btcB.decimals());
    }

    function test_Mint() public {
        assertEq(btcB.owner(), owner, "Initial owner check failed");
        vm.startPrank(owner);
        btcB.mint(address(0x3), 100 * 10 ** btcB.decimals());
        vm.stopPrank();
        assertEq(btcB.balanceOf(address(0x3)), 100 * 10 ** btcB.decimals());
    }

    function test_PauseAndUnpause() public {
        vm.prank(owner);
        btcB.pause();
        assertTrue(btcB.paused());

        vm.prank(owner);
        btcB.unpause();
        assertFalse(btcB.paused());
    }

    function test_TransferWhenPaused() public {
        vm.prank(owner);
        btcB.pause();
        assertTrue(btcB.paused());

        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        btcB.transfer(address(0x3), 10);
    }

}
