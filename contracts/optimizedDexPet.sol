// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

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

    constructor() ERC721("DexPet", "DPET") {
        owner = msg.sender;
    }

    struct Pet {
        uint16 breed; // Reduced size for storage optimization
        uint16 yearOfBirth; // Reduced size for storage optimization
        uint256 petId;
        uint256 price;
        Category petCategory;
        string name;
        string color;
        string picture;
        string description;
        bool isAdopted;
        address adopter;
    }

    struct Auction {
        uint256 petId;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool isActive;
    }

    struct Bid {
        uint256 bidId;
        uint256 petId;
        uint256 amountBidded;
        address bidder;
        BidStatus bid_status;
    }

    mapping(uint256 => Pet) public petIdToPets; // mapping to store pets by their ID.
    mapping(uint256 => Auction) public petIdToAuction; // Mapping Auction to PetID.
    mapping(address => Bid[]) public userToBids; // Mapping users to bids.
    mapping(uint256 => mapping(address => Bid[])) public petIdToUserBids; // Mapping petId => userAddress => bids
    mapping(uint256 => Bid[]) public petIdToBids; // Mapping petId to bids

    uint256 public petId; // Variable to keep track of the number of pets
    uint256 public totalBids; // Variable to keep track of the number of total bids

    event AuctionCreated(
        uint256 indexed petId,
        uint256 startingPrice,
        uint256 endTime
    );
    event BidPlaced(uint256 indexed petId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed petId, address winner, uint256 amount);
    event NFTMinted(uint256 indexed petId, address highestBidder);
    event PetAdded(
        uint256 indexed petId,
        string name,
        uint16 breed, // Updated type
        string color,
        uint256 price,
        string picture,
        uint16 yearOfBirth, // Updated type
        string description,
        Category category
    );
    event BidCancelled(uint256 indexed petId, address bidder, uint256 amount);

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function addPet(
        string memory name,
        uint16 breed, // Updated type
        string memory color,
        uint256 price,
        string memory picture,
        uint16 yearOfBirth, // Updated type
        string memory description,
        Category category
    ) public onlyOwner {
        petId++;
        Pet memory pet = Pet({
            petId: petId,
            name: name,
            breed: breed,
            color: color,
            price: price,
            picture: picture,
            isAdopted: false,
            yearOfBirth: yearOfBirth,
            description: description,
            petCategory: category,
            adopter: address(0)
        });
        petIdToPets[petId] = pet;

        emit PetAdded(
            petId,
            name,
            breed,
            color,
            price,
            picture,
            yearOfBirth,
            description,
            category
        );
    }

    function listPetForAuction(
        uint256 _petId,
        uint256 _startingPrice,
        uint256 _auctionDuration
    ) external onlyOwner {
        require(!petIdToPets[_petId].isAdopted, "Pet is already adopted");
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(
            _auctionDuration > 0,
            "Auction duration must be greater than 0"
        );

        uint256 endTime = block.timestamp + _auctionDuration;
        petIdToAuction[_petId] = Auction({
            petId: _petId,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: endTime,
            isActive: true
        });

        emit AuctionCreated(_petId, _startingPrice, endTime);
    }

    function placeBid(uint256 _petId) external payable {
        Auction storage auction = petIdToAuction[_petId];
        require(auction.petId != 0, "Auction does not exist");
        require(msg.sender != address(0), "Invalid sender address");
        require(auction.isActive, "Auction is not active");
        require(!petIdToPets[_petId].isAdopted, "Pet is already adopted");
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(
            msg.value > auction.highestBid,
            "Bid must be higher than current highest bid"
        );

        if (auction.highestBidder != address(0)) {
            // Refund the previous highest bidder
            (bool success, ) = payable(auction.highestBidder).call{
                value: auction.highestBid
            }("");
            require(success, "Refund Failed");
        }

        // Check if the user has any open bids for this pet
        bool hasOpenBid = false;
        uint256 userBidsLength = petIdToUserBids[_petId][msg.sender].length;
        for (uint256 i = 0; i < userBidsLength; i++) {
            if (
                petIdToUserBids[_petId][msg.sender][i].bid_status ==
                BidStatus.Open
            ) {
                hasOpenBid = true;
                break;
            }
        }
        require(!hasOpenBid, "You already have an open bid for this pet");

        uint256 userBidId = userToBids[msg.sender].length + 1;

        Bid memory newBid = Bid({
            bidId: userBidId,
            petId: _petId,
            amountBidded: msg.value,
            bidder: msg.sender,
            bid_status: BidStatus.Open
        });

        userToBids[msg.sender].push(newBid);
        petIdToUserBids[_petId][msg.sender].push(newBid);
        petIdToBids[_petId].push(newBid);

        totalBids++;

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(_petId, msg.sender, msg.value);
    }

    function cancelBid(uint256 _petId, uint256 _bidId) external {
        require(msg.sender != address(0), "Invalid sender address");
        Auction storage auction = petIdToAuction[_petId];
        require(auction.isActive, "Auction is not active");
        require(
            petIdToUserBids[_petId][msg.sender].length > 0,
            "You have not bid on this pet"
        );

        Bid storage bid = petIdToUserBids[_petId][msg.sender][_bidId];
        require(bid.bid_status == BidStatus.Open, "Your bid is not open");

        if (auction.highestBidder == msg.sender) {
            auction.highestBid = 0;
            auction.highestBidder = address(0);
        }

        bid.bid_status = BidStatus.Cancelled;
        userToBids[msg.sender][_bidId].bid_status = BidStatus.Cancelled;

        // Refund the bid amount to the bidder
        (bool success, ) = payable(msg.sender).call{value: bid.amountBidded}(
            ""
        );
        require(success, "Failed to refund bid amount");

        emit BidCancelled(_petId, msg.sender, bid.amountBidded);
    }

    function endAuction(uint256 _petId, uint256 _bidId) external onlyOwner {
        Auction storage auction = petIdToAuction[_petId];
        require(auction.isActive, "Auction is not active");
        require(
            block.timestamp >= auction.endTime,
            "Auction has not ended yet"
        );

        if (auction.highestBidder != address(0)) {
            Pet storage pet = petIdToPets[_petId];
            pet.isAdopted = true;
            pet.price = auction.highestBid;
            pet.adopter = auction.highestBidder;

            Bid storage bid = petIdToUserBids[_petId][auction.highestBidder][
                _bidId
            ];
            auction.isActive = false;
            bid.bid_status = BidStatus.Accepted;
            userToBids[auction.highestBidder][_bidId].bid_status = BidStatus
                .Accepted;

            for (uint256 i = 0; i < petIdToBids[_petId].length; i++) {
                Bid storage petBid = petIdToBids[_petId][i];
                if (
                    petBid.bidder != auction.highestBidder &&
                    petBid.bid_status == BidStatus.Open
                ) {
                    petBid.bid_status = BidStatus.Rejected;
                }
            }

            // Mint NFT to the highest bidder
            _safeMint(auction.highestBidder, _petId);
            _setTokenURI(_petId, pet.picture);

            emit NFTMinted(_petId, auction.highestBidder);
            emit AuctionEnded(
                _petId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            auction.isActive = false;
            emit AuctionEnded(_petId, address(0), 0);
        }
    }

    function getUnadoptedPets() external view returns (Pet[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= petId; i++) {
            if (!petIdToPets[i].isAdopted) count++;
        }

        Pet[] memory pets = new Pet[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= petId; i++) {
            if (!petIdToPets[i].isAdopted) {
                pets[index] = petIdToPets[i];
                index++;
            }
        }
        return pets;
    }

    function getAdoptedPets() external view returns (Pet[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= petId; i++) {
            if (petIdToPets[i].isAdopted) count++;
        }

        Pet[] memory pets = new Pet[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= petId; i++) {
            if (petIdToPets[i].isAdopted) {
                pets[index] = petIdToPets[i];
                index++;
            }
        }
        return pets;
    }

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
