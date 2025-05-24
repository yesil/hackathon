// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // Using OpenZeppelin's IERC20 interface

/**
 * @title GatedLinkAccessManager
 * @dev Manages access to private links by requiring payment in a specific ERC20 token.
 * Payments are transferred directly from the buyer to the content creator.
 */
contract GatedLinkAccessManager {

    // --- State Variables ---

    IERC20 public immutable yourERC20Token; // The ERC20 token used for payments

    struct GatedLink {
        bytes32 linkId;       // Unique identifier for the link (e.g., hash of the off-chain URL)
        address creator;      // Address of the content creator to receive payment
        uint256 priceInERC20; // Price directly in yourERC20Token units
        bool isActive;        // Whether this link is active for new purchases
    }

    mapping(bytes32 => GatedLink) public gatedLinkInfo;
    mapping(bytes32 => mapping(address => bool)) public hasAccess; // linkId => user => hasAccess

    address public owner; // To manage administrative functions like creating links

    // --- Events ---

    event LinkCreated(
        bytes32 indexed linkId,
        address indexed creator,
        uint256 priceInERC20,
        bool isActive
    );

    event LinkActivitySet(
        bytes32 indexed linkId,
        bool isActive
    );

    event PaymentMade(
        bytes32 indexed linkId,
        address indexed buyer,
        address indexed creator,
        uint256 amountPaid
    );

    event AccessGranted(
        bytes32 indexed linkId,
        address indexed buyer
    );

    // --- Modifiers ---

    modifier onlyOwner() {
        require(msg.sender == owner, "GatedLinkAccessManager: Caller is not the owner");
        _;
    }

    // --- Constructor ---

    /**
     * @param _erc20TokenAddress The address of the ERC20 token to be used for payments.
     */
    constructor(address _erc20TokenAddress) {
        require(_erc20TokenAddress != address(0), "GatedLinkAccessManager: Invalid ERC20 token address");
        yourERC20Token = IERC20(_erc20TokenAddress);
        owner = msg.sender;
    }

    // --- Administrative Functions ---

    /**
     * @dev Creates a new gated link entry. Only callable by the owner.
     * @param _linkId A unique identifier for the link.
     * @param _creator The address of the content creator who will receive payments.
     * @param _priceInERC20 The price of the link in the smallest unit of yourERC20Token.
     * @param _initialIsActive The initial active state of the link.
     */
    function createLink(
        bytes32 _linkId,
        address _creator,
        uint256 _priceInERC20,
        bool _initialIsActive
    ) external onlyOwner {
        require(_linkId != bytes32(0), "GatedLinkAccessManager: Link ID cannot be zero");
        require(gatedLinkInfo[_linkId].creator == address(0), "GatedLinkAccessManager: Link ID already exists"); // Ensure linkId is unique
        require(_creator != address(0), "GatedLinkAccessManager: Invalid creator address");
        require(_priceInERC20 > 0, "GatedLinkAccessManager: Price must be greater than zero");

        gatedLinkInfo[_linkId] = GatedLink({
            linkId: _linkId,
            creator: _creator,
            priceInERC20: _priceInERC20,
            isActive: _initialIsActive
        });

        emit LinkCreated(_linkId, _creator, _priceInERC20, _initialIsActive);
    }

    /**
     * @dev Sets the active state of a gated link. Only callable by the owner.
     * @param _linkId The identifier of the link.
     * @param _isActive The new active state.
     */
    function setLinkActivity(bytes32 _linkId, bool _isActive) external onlyOwner {
        require(gatedLinkInfo[_linkId].creator != address(0), "GatedLinkAccessManager: Link ID does not exist");

        gatedLinkInfo[_linkId].isActive = _isActive;
        emit LinkActivitySet(_linkId, _isActive);
    }

    // --- Public Functions ---

    /**
     * @dev Allows a user to pay for access to a gated link.
     * The user must have approved this contract to spend their ERC20 tokens beforehand.
     * Funds are transferred directly from the buyer (msg.sender) to the link's creator.
     * @param _linkId The identifier of the link to purchase access for.
     */
    function payForAccess(bytes32 _linkId) external {
        GatedLink storage link = gatedLinkInfo[_linkId]; // Using storage pointer for efficiency

        require(link.creator != address(0), "GatedLinkAccessManager: Link ID does not exist");
        require(link.isActive, "GatedLinkAccessManager: Link is not active for purchase");
        require(!hasAccess[_linkId][msg.sender], "GatedLinkAccessManager: Access already purchased");

        uint256 currentPrice = link.priceInERC20;

        // Transfer the ERC20 tokens from the buyer (msg.sender) to the creator
        // Requires buyer to have called `approve` on yourERC20Token for this contract's address
        bool success = yourERC20Token.transferFrom(msg.sender, link.creator, currentPrice);
        require(success, "GatedLinkAccessManager: ERC20 transfer failed");

        hasAccess[_linkId][msg.sender] = true;

        emit PaymentMade(_linkId, msg.sender, link.creator, currentPrice);
        emit AccessGranted(_linkId, msg.sender);
    }

    // --- View Functions ---

    /**
     * @dev Checks if a user has access to a specific gated link.
     * @param _linkId The identifier of the link.
     * @param _user The address of the user to check.
     * @return bool True if the user has access, false otherwise.
     */
    function checkAccess(bytes32 _linkId, address _user) external view returns (bool) {
        return hasAccess[_linkId][_user];
    }

    /**
     * @dev Retrieves the details of a gated link.
     * @param _linkId The identifier of the link.
     * @return GatedLink The link details.
     */
    function getLinkDetails(bytes32 _linkId) external view returns (GatedLink memory) {
        return gatedLinkInfo[_linkId];
    }

    // --- Owner Management (Optional, if you need to transfer ownership) ---
    /**
     * @dev Transfers ownership of the contract to a new account. Only callable by the current owner.
     * @param newOwner The address of the new owner.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "GatedLinkAccessManager: New owner is the zero address");
        owner = newOwner;
    }
}
