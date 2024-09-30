// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

import "./Utils.sol";

contract DexPet is ERC721, ERC721URIStorage {
    enum Category {
        Cat,
        Dog,
        Bird
    }

    enum BidStatus {
        Open,
        Accepted,
        Cancelled,
        Rejected
    }

    struct Pet {
        uint256 petId;
        string name;
        uint256 breed;
        string color;
        uint256 price;
        string picture;
        uint256 yearOfBirth;
        string description;
        Category petCategory;
        bool isAdopted;
        address adopter;
    }
    struct Auction {
        uint256 petId;
        uint256 startingPrice;
        uint256 highestBid;
        uint256 endTime;
        bool isActive;
        address highestBidder;
    }
    struct Bid {
        uint256 bidId;
        uint256 petId;
        uint256 amountBidded;
        address bidder;
        BidStatus bid_status;
    }

    mapping(uint256 => Pet) private petIdToPet; // mapping to store pets by their ID.

    mapping(uint256 => Auction) private petIdToAuction; //Mapping Auction to PetID.

    Auction[] private allPetAuctions;

    mapping(address => Bid[]) private userToBids; //Mapping users to bids.

    mapping(uint256 => mapping(address => Bid[])) private petIdToUserBids; //Mapping petId => userAddress => bids

    mapping(uint256 => Bid[]) private petIdToBids; //Mapping petId to bids

    uint256 public petId; // variable to keep track of the number of pets
    uint256 public totalBids; // variable to keep track of the number of total bids

    address public owner;

    constructor() ERC721("DexPet", "DPET") {
        owner = msg.sender;
    }

    // @dev: private functions
    function onlyOwner() private view {
        if (msg.sender != owner) {
            revert Errors.OnlyOwner();
        }
    }

    function sanityCheck() private view {
        if (msg.sender == address(0)) {
            revert Errors.ZeroAddressError();
        }
    }

    // @user: user functions

    // @user: only Owner functions
    function addPet(
        string memory name,
        uint256 breed, // why is breed a uint
        string memory color,
        uint256 price,
        string memory picture,
        uint256 yearOfBirth,
        string memory description,
        Category category
    ) public {
        sanityCheck();
        onlyOwner();

        petId++;
        petIdToPet[petId] = Pet(
            petId,
            name,
            breed,
            color,
            price,
            picture,
            yearOfBirth,
            description,
            category,
            false,
            address(0)
        );

        emit Events.PetAdded(
            petId,
            name,
            breed,
            color,
            price,
            picture,
            yearOfBirth,
            description,
            uint8(category)
        );
    }

    // an owner can list one pet multiple times on aunction

    function listPetForAuction(
        uint256 _petId,
        uint256 _startingPrice,
        uint256 _auctionDuration
    ) external {
        sanityCheck();
        onlyOwner();

        Pet memory pet = petIdToPet[_petId];
        // what if a user tries to list a pet that is in auction?
        Auction memory auction = petIdToAuction[_petId];

        if (auction.isActive) {
            revert Errors.PetIsInOpenBid();
        }

        if (pet.isAdopted) {
            revert Errors.PetAlreadyAdopted();
        }

        // why?
        if (_startingPrice <= 0) {
            revert Errors.StartPriceCannotZero();
        }

        if (_auctionDuration <= 0) {
            revert Errors.DurationCannotBeZero();
        }

        uint256 endTime = block.timestamp + _auctionDuration;

        Auction memory newAuction = Auction({
            petId: _petId,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            isActive: true
        });

        petIdToAuction[_petId] = newAuction;
        allPetAuctions.push(newAuction);

        emit Events.AuctionCreated(_petId, _startingPrice, endTime);
    }

    function endAuction(uint256 _petId) external {
        sanityCheck();
        onlyOwner();

        Auction memory auction = petIdToAuction[_petId];

        if (!auction.isActive) {
            revert Errors.AuctionNotActive();
        }

        // i don't understand this check
        if (block.timestamp < auction.endTime) {
            revert Errors.AuctionIsActive();
        }

        uint256 currentHighestBidId = petIdToBids[petId].length;

        if (auction.highestBidder != address(0)) {
            Pet storage pet = petIdToPet[_petId];
            pet.isAdopted = true;
            pet.price = auction.highestBid;
            pet.adopter = auction.highestBidder;

            // Update the bid status to accepted
            Bid storage bid = petIdToUserBids[_petId][auction.highestBidder][
                currentHighestBidId
            ];
            petIdToAuction[_petId].isActive = false;
            bid.bid_status = BidStatus.Accepted;
            userToBids[auction.highestBidder][currentHighestBidId]
                .bid_status = BidStatus.Accepted;

            // Mint NFT to the highest bidder
            _safeMint(auction.highestBidder, _petId);
            _setTokenURI(_petId, pet.picture);

            emit Events.NFTMinted(_petId, auction.highestBidder, pet.petId);
            emit Events.AuctionEnded(
                _petId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            petIdToAuction[_petId].isActive = false;
            emit Events.AuctionEnded(_petId, address(0), 0);
        }
    }

    // @dev: not onlyOwner

    function placeBid(uint256 _petId) external payable {
        sanityCheck();

        Auction memory auction = petIdToAuction[_petId];

        // why
        if (auction.petId == 0) {
            revert Errors.InvalidAuction();
        }

        if (!auction.isActive) {
            revert Errors.AuctionNotActive();
        }

        if (petIdToPet[_petId].isAdopted) {
            revert Errors.PetAlreadyAdopted();
        }

        if (block.timestamp > auction.endTime) {
            revert Errors.AuctionHasEnded();
        }

        if (msg.value <= auction.highestBid) {
            revert Errors.BidTooLow();
        }

        //Get the Id of the prev bidder

        uint256 prevBidId = petIdToBids[petId].length;
        uint256 prevUserBidId = userToBids[auction.highestBidder].length;

        if (auction.highestBidder != address(0)) {
            // I guess there's a reentrancy flaw here or maybe I've fixed it

            // Refund the previous highest bidder

            petIdToBids[_petId][prevBidId - 1].bid_status = BidStatus.Rejected;
            userToBids[auction.highestBidder][prevUserBidId - 1]
                .bid_status = BidStatus.Rejected;

            (bool success, ) = payable(auction.highestBidder).call{
                value: auction.highestBid
            }("");

            if (!success) {
                revert Errors.PrevBidderRefundFailed();
            }
        }

        Bid memory newBid = Bid({
            bidId: prevUserBidId + 1,
            petId: _petId,
            amountBidded: msg.value,
            bidder: msg.sender,
            bid_status: BidStatus.Open
        });

        userToBids[msg.sender].push(newBid);

        petIdToUserBids[_petId][msg.sender].push(newBid);

        petIdToBids[_petId].push(newBid);

        //Increment total bids
        totalBids++;

        petIdToAuction[_petId].highestBid = msg.value;
        petIdToAuction[_petId].highestBidder = msg.sender;

        emit Events.BidPlaced(_petId, msg.sender, msg.value);
    }

    function cancelBid(uint256 _petId, uint256 _bidId) external {
        sanityCheck();

        if (!petIdToAuction[_petId].isActive) {
            revert Errors.AuctionNotActive();
        }

        if (petIdToUserBids[_petId][msg.sender].length <= 0) {
            revert Errors.NoActivePetBid();
        }

        if (
            petIdToUserBids[_petId][msg.sender][_bidId].bid_status !=
            BidStatus.Open
        ) {
            revert Errors.YourBidIsNotOpen();
        }

        Bid storage bid = petIdToUserBids[_petId][msg.sender][_bidId];

        //Check if user is the higest bidder at this point
        Auction memory auction = petIdToAuction[_petId];
        if (auction.highestBidder == msg.sender) {
            auction.highestBid = 0;
            auction.highestBidder = address(0);
        }

        bid.bid_status = BidStatus.Cancelled;
        userToBids[msg.sender][_bidId].bid_status = BidStatus.Cancelled;

        //Refund the bid amount to the bidder
        (bool success, ) = payable(msg.sender).call{value: bid.amountBidded}(
            ""
        );
        if (!success) {
            revert Errors.PrevBidderRefundFailed();
        }

        emit Events.BidCancelled(_petId, msg.sender, bid.amountBidded);
    }

    // @dev: getter functions

    function getPet(uint256 _petId) external view returns (Pet memory) {
        return petIdToPet[_petId];
    }

    function getPetAuction(
        uint256 _petId
    ) external view returns (Auction memory) {
        return petIdToAuction[_petId];
    }

    function getAllAuctions() external view returns(Auction[] memory){
        return allPetAuctions;
    }

    function getAdoptedPets() external view returns (Pet[] memory) {
        onlyOwner();
        Pet[] memory _petListings = new Pet[](petId);
        uint256 count = 0;
        for (uint256 i = 0; i < petId; i++) {
            if (petIdToPet[i + 1].isAdopted == true) {
                _petListings[count] = petIdToPet[i + 1];
                count++;
            }
        }
        return _petListings;
    }

    function getPetBids(uint256 _petId) external view returns (Bid[] memory) {
        return petIdToBids[_petId];
    }

    function getUserBids(
        uint256 _petId,
        address _user
    ) external view returns (Bid[] memory) {
        return petIdToUserBids[_petId][_user];
    }

    function getUserBidsLength(address _user) external view returns (uint256) {
        return userToBids[_user].length;
    }

    // @dev: inner functions

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
