// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {GatedLinkAccessManager} from "../src/GatedLinkAccessManager.sol";
import {BitcoinOnAvalanche} from "../src/BTC.B.sol"; // Mock ERC20

contract GatedLinkAccessManagerTest is Test {
    GatedLinkAccessManager public manager;
    BitcoinOnAvalanche public mockERC20;

    address public owner = address(0x1);
    address public creator = address(0x2);
    address public buyer = address(0x3);
    address public otherUser = address(0x4);

    bytes32 public linkId = keccak256(abi.encodePacked("http://example.com/link1"));
    uint256 public linkPrice = 100 * 10 ** 18; // Assuming 18 decimals for mockERC20

    function setUp() public {
        // Deploy mock ERC20, mint some tokens to the buyer
        vm.prank(owner);
        mockERC20 = new BitcoinOnAvalanche(buyer, owner); // buyer gets initial supply, owner is contract owner

        // Deploy GatedLinkAccessManager with the mock ERC20 token address
        vm.prank(owner); // manager owner will be address(0x1)
        manager = new GatedLinkAccessManager(address(mockERC20));
    }

    function test_InitialOwner() public view {
        assertEq(manager.owner(), owner, "Initial owner not set correctly");
    }

    function test_CreateLink() public {
        vm.prank(owner);
        manager.createLink(linkId, creator, linkPrice, true);

        GatedLinkAccessManager.GatedLink memory link = manager.getLinkDetails(linkId);
        assertEq(link.linkId, linkId, "Link ID mismatch");
        assertEq(link.creator, creator, "Creator mismatch");
        assertEq(link.priceInERC20, linkPrice, "Price mismatch");
        assertTrue(link.isActive, "Link should be active");
    }

    function test_CreateLink_NotOwner() public {
        vm.prank(otherUser);
        vm.expectRevert("GatedLinkAccessManager: Caller is not the owner");
        manager.createLink(linkId, creator, linkPrice, true);
    }

    function test_SetLinkActivity() public {
        vm.prank(owner);
        manager.createLink(linkId, creator, linkPrice, true);

        vm.prank(owner);
        manager.setLinkActivity(linkId, false);
        GatedLinkAccessManager.GatedLink memory link = manager.getLinkDetails(linkId);
        assertFalse(link.isActive, "Link should be inactive");

        vm.prank(owner);
        manager.setLinkActivity(linkId, true);
        link = manager.getLinkDetails(linkId);
        assertTrue(link.isActive, "Link should be active again");
    }

    function test_PayForAccess() public {
        // 1. Owner creates a link
        vm.prank(owner);
        manager.createLink(linkId, creator, linkPrice, true);

        // 2. Buyer approves the manager contract to spend their mockERC20 tokens
        vm.startPrank(buyer);
        mockERC20.approve(address(manager), linkPrice);

        // 3. Buyer pays for access
        uint256 buyerInitialBalance = mockERC20.balanceOf(buyer);
        uint256 creatorInitialBalance = mockERC20.balanceOf(creator);

        manager.payForAccess(linkId);
        vm.stopPrank();

        // 4. Check access and balances
        assertTrue(manager.checkAccess(linkId, buyer), "Buyer should have access");
        assertEq(mockERC20.balanceOf(buyer), buyerInitialBalance - linkPrice, "Buyer balance incorrect");
        assertEq(mockERC20.balanceOf(creator), creatorInitialBalance + linkPrice, "Creator balance incorrect");
    }

    function test_PayForAccess_InactiveLink() public {
        vm.prank(owner);
        manager.createLink(linkId, creator, linkPrice, false); // Link is inactive

        vm.startPrank(buyer);
        mockERC20.approve(address(manager), linkPrice);
        vm.expectRevert("GatedLinkAccessManager: Link is not active for purchase");
        manager.payForAccess(linkId);
        vm.stopPrank();
    }

    function test_PayForAccess_AlreadyPurchased() public {
        vm.prank(owner);
        manager.createLink(linkId, creator, linkPrice, true);

        vm.startPrank(buyer);
        mockERC20.approve(address(manager), linkPrice);
        manager.payForAccess(linkId); // First purchase

        // Attempt second purchase
        mockERC20.approve(address(manager), linkPrice); // Re-approve just in case
        vm.expectRevert("GatedLinkAccessManager: Access already purchased");
        manager.payForAccess(linkId);
        vm.stopPrank();
    }


    function test_TransferOwnership() public {
        vm.prank(owner);
        manager.transferOwnership(otherUser);
        assertEq(manager.owner(), otherUser, "Ownership not transferred");
    }

    function test_TransferOwnership_NotOwner() public {
        vm.prank(otherUser);
        vm.expectRevert("GatedLinkAccessManager: Caller is not the owner");
        manager.transferOwnership(creator);
    }

     function test_GetLinkDetails_NonExistentLink() public view {
        GatedLinkAccessManager.GatedLink memory link = manager.getLinkDetails(bytes32(0));
        assertEq(link.creator, address(0), "Creator should be zero for non-existent link");
        assertEq(link.priceInERC20, 0, "Price should be zero for non-existent link");
    }

    function test_CheckAccess_NoAccess() public view {
        assertFalse(manager.checkAccess(linkId, buyer), "Should not have access initially");
    }

} 