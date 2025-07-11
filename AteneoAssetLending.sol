// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.2 <0.9.0;

/// @notice Structure representing an asset available for lending
struct Asset {
    address owner;
    string name;
    uint rental_fee;
    bool borrowed;
    address currentContract;
}

contract AteneoLendingContract {

    uint constant PENALTY = 2000000; // ADDED: Set the penalty fee for returning an asset late
    uint constant DEPOSIT = 1000000; // ADDED: Set the security deposit for all borrowers

    mapping(address => bool) public flags; // Mapping of flagged users
    mapping(address => bool) private borrowers; // Mapping of borrowers and borrowing status
    Asset[] public listedAssets; // Array of assets for borrowing

    /// @notice Modifier that checks if user is flagged
    modifier flagged() {
        require(flags[msg.sender] == true, "You are not flagged."); // ADDED: Modifier to check if user is flagged, else revert with an error message saying that user is not flagged
        _;
    }

    /// @notice Modifier that checks if user is not flagged
    modifier notFlagged() {
        require(flags[msg.sender] == false, "You are flagged! Pay the penalty first."); // ADDED: Modifier to check if user is not flagged, else revert with an error message for paying penalty
        _;
    }

    /// @notice Modifier that checks if user is not borrowing
    modifier notBorrowing() {
        require(borrowers[msg.sender] == false, "You're already borrowing an asset!"); // ADDED: Modifier to check if user is not currently borrowing an asset
        _;
    }

    /// @notice List a new asset for lending
    /// @param _name The name of the asset
    /// @param _rental_fee The rental fee for borrowing the asset
    function listItem(string memory _name, uint _rental_fee) external {
        // ADDED: Add asset to the list of available assets
        Asset memory newAsset = Asset({ 
            owner: msg.sender,
            name: _name,
            rental_fee: _rental_fee,
            borrowed: false,
            currentContract: address(0)
        });

        listedAssets.push(newAsset);
    }

    /// @notice Borrow an asset by ID, paying rental and deposit fees
    /// @param _itemId The index of the asset in the list
    function borrow(uint _itemId) external payable notBorrowing notFlagged {
        require(_itemId < listedAssets.length, "Asset does not exist."); // ADDED: Check if _itemId is valid
        Asset storage asset = listedAssets[_itemId];
        
        require(asset.borrowed == false, "Asset is already borrowed!"); // ADDED: Check if asset is already borrowed

        uint payment = asset.rental_fee + DEPOSIT; // ADDED: Check if the payment is correct
        require(msg.value == payment, "Insufficient payment.");

        // ADDED: Handle borrowing action, transfer deposit and rental fees, and update borrower and item status
        AssetContract newAssetContract = new AssetContract(address(this), asset.owner, msg.sender, _itemId);
        asset.borrowed = true;
        asset.currentContract = address(newAssetContract);

        borrowers[msg.sender] = true;

        payable(asset.owner).transfer(asset.rental_fee);
    }

    /// @notice Mark an asset as returned (can only be called by the AssetContract)
    /// @param _itemId The index of the asset in the list
    function markReturned(uint _itemId, address _borrower) external {
        require(_itemId < listedAssets.length, "Asset does not exist.");
        Asset storage asset = listedAssets[_itemId];
        
        // ADDED: Validate if caller is AssetContract
        require(msg.sender == asset.currentContract, "Unauthorized caller!");

        // ADDED: Validate if asset is borrowed
        require(asset.borrowed == true, "Asset is not borrowed!");

        // TO ADD: Update borrower and item status
        asset.borrowed = false;
        asset.currentContract = address(0);
        borrowers[_borrower] = false;
    }

    /// @notice Flag a borrower who returned an asset late (can only be called by the AssetContract)
    /// @param _borrower The address of the borrower to be flagged
    /// @param _itemId The index of the borrowed asset
    function flag(address _borrower, uint _itemId) external {
        // TO ADD: Validate _itemId
        // TO ADD: Validate if caller is AssetContract
        // TO ADD: Update borrower status
    }

    /// @notice Pay the penalty fee to remove the flagged status
    function payPenalty() external payable flagged {
        // TO ADD: Check penalty payment amount and update borrower status
    }

    /// @notice Retrieve the full list of listed assets
    /// @return An array of all listed assets
    function getListedAssets() public view returns (Asset[] memory) {
        return listedAssets; // ADDED: Return the array of listed assets
    }
}

contract AssetContract {

    address private parent;
    address public owner;
    address public borrower;
    uint public itemId;
    uint public deadline;
    bool public returned;
    uint private duration = 30 seconds; // Set to 30 seconds only for testing purposes

    /// @notice Allow this contract to receive ether
    receive() external payable {} // ADDED: fallback function to receive Ether transfers

    /// @notice Constructor sets initial state and deadline
    /// @param _parent The address of the AteneoLendingContract
    /// @param _owner The original owner of the asset
    /// @param _borrower The borrower of the asset
    /// @param _itemId The index of the borrowed asset
    constructor(address _parent, address _owner, address _borrower, uint _itemId) {
        // ADDED: Constructor function statements
        parent = _parent;
        owner = _owner;
        borrower = _borrower;
        itemId = _itemId;
        deadline = block.timestamp + duration;
        returned = false;
    }

    /// @notice Called by borrower to return the item, returns the deposit fee, and triggers penalty if overdue
    function returnItem() external {
        require(msg.sender == borrower, "You are not the borrower!"); // ADDED: Verify the borrower
        require(returned == false, "Asset already returned."); // ADDED: Verify if the asset has already been returned
        
        // ADDED: Handle return actions, update the return status, check return timestamp, and handle penalties if overdue
        returned = true;
        if (block.timestamp > deadline) {
            AteneoLendingContract(parent).flag(borrower, itemId);
        }
        AteneoLendingContract(parent).markReturned(itemId, borrower);
        payable(borrower).transfer(address(this).balance);
    }
}
