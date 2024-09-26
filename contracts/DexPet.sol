// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
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
        Closed,
        Cancelled
    }

    constructor() ERC721("DexPet", "DPET") {
        owner = msg.sender;
    }

    struct Pet {
        uint256 petId;
        string name;
        uint256 breed;
        string color;
        uint256 price;
        string picture;
        bool isAdopted;
        uint256 yearOfBirth;
        string description;
        Category petCategory;
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
    mapping(uint256 => Auction) public petIdToAuction; //Mapping Auction to PetID.
    mapping(address => Bid[]) public userToBids; //Mapping users to bids.
    mapping(uint256 => mapping(address => Bid[])) public petIdToUserBids; //Mapping petId => userAddress => bids
    mapping(uint256 => Bid[]) public petIdToBids; //Mapping petId to bids

    uint256 public petId; // variable to keep track of the number of pets
    uint256 public totalBids; // variable to keep track of the number of total bids

    event AuctionCreated(
        uint256 indexed petId,
        uint256 startingPrice,
        uint256 endTime
    );
    event BidPlaced(uint256 indexed petId, address bidder, uint256 amount);
    event AuctionEnded(uint256 indexed petId, address winner, uint256 amount);
    event NFTMinted(uint256 _petId, address highestBidder, uint256 tokenId);
    event PetAdded(
        uint256 indexed petId,
        string name,
        uint256 breed,
        string color,
        uint256 price,
        string picture,
        uint256 yearOfBirth,
        string description,
        Category category
    );
    event BidCancelled(uint256 indexed petId, address bidder, uint256 amount);

    address public owner;

    function addPet(
        string memory name,
        uint256 breed,
        string memory color,
        uint256 price,
        string memory picture,
        uint256 yearOfBirth,
        string memory description,
        Category category
    ) public onlyOwner {
        petId++;
        Pet storage pet = petIdToPets[petId];
        pet.petId = petId;
        pet.name = name;
        pet.breed = breed;
        pet.color = color;
        pet.price = price;
        pet.picture = picture;
        pet.yearOfBirth = yearOfBirth;
        pet.description = description;
        pet.petCategory = category;
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
    ) public onlyOwner {
        require(
            petIdToPets[_petId].isAdopted == false,
            "Pet is already adopted"
        );
        require(_startingPrice >= 0, "Starting price must be 0");
        require(
            _auctionDuration > 0,
            "Auction duration must be greater than 0 days"
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

    function placeBid(uint256 _petId) public payable {
        Auction storage auction = petIdToAuction[_petId];
        require(auction.isActive, "Auction is not active");
        require(
            petIdToPets[_petId].isAdopted == false,
            "Pet is already adopted"
        );
        require(block.timestamp < auction.endTime, "Auction has ended");
        require(
            petIdToUserBids[_petId][msg.sender].length == 0,
            "You have already bid on this pet"
        );
        require(
            msg.value > auction.highestBid,
            "Bid must be higher than current highest bid"
        );

        if (auction.highestBidder != address(0)) {
            // Refund the previous highest bidder
            (bool success, ) = payable(auction.highestBidder).call{
                value: auction.highestBid
            }("");
            require(success, "Failed to refund previous highest bidder");
        }

        //Generate a unique bid ID for the user
        uint256 userBidId = userToBids[msg.sender].length + 1;
        Bid storage bid = userToBids[msg.sender][userBidId];
        bid.bidId = userBidId;
        bid.petId = _petId;
        bid.amountBidded = msg.value;
        bid.bidder = msg.sender;
        bid.bid_status = BidStatus.Open;
        userToBids[msg.sender].push(bid);

        petIdToUserBids[_petId][msg.sender].push(bid);
        petIdToBids[_petId].push(bid);

        //Increment total bids
        totalBids++;

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(_petId, msg.sender, msg.value);
    }

    function cancelBid(uint256 _petId, uint256 _bidId) public {
        require(
            petIdToUserBids[_petId][msg.sender].length > 0,
            "You have not bid on this pet"
        );
        require(
            petIdToUserBids[_petId][msg.sender][_bidId].bid_status ==
                BidStatus.Open,
            "Your bid is not open"
        );
        petIdToUserBids[_petId][msg.sender][_bidId].bid_status = BidStatus
            .Cancelled;

        //Refund the bid amount to the bidder
        (bool success, ) = payable(msg.sender).call{
            value: petIdToUserBids[_petId][msg.sender][_bidId].amountBidded
        }("");
        require(success, "Failed to refund previous highest bidder");
        emit BidCancelled(
            _petId,
            msg.sender,
            petIdToUserBids[_petId][msg.sender][_bidId].amountBidded
        );
    }

    function endAuction(uint256 _petId) public onlyOwner {
        Auction storage auction = petIdToAuction[_petId];
        require(auction.isActive, "Auction is not active");
        require(
            block.timestamp >= auction.endTime,
            "Auction has not ended yet"
        );

        auction.isActive = false;
        Pet storage pet = petIdToPets[_petId];
        pet.isAdopted = true;
        pet.price = auction.highestBid;
        pet.adopter = auction.highestBidder;

        if (auction.highestBidder != address(0)) {
            // Transfer the pet to the highest bidder
            // You might want to implement a transfer function or update ownership here
            (bool success, ) = payable(auction.highestBidder).call{
                value: auction.highestBid
            }("");
            require(success, "Failed to refund previous highest bidder");
            // Mint NFT to the highest bidder
            _safeMint(auction.highestBidder, _petId);
            _setTokenURI(_petId, pet.picture);
            emit NFTMinted(_petId, auction.highestBidder, pet.petId);
            emit AuctionEnded(
                _petId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            emit AuctionEnded(_petId, address(0), 0);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
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
