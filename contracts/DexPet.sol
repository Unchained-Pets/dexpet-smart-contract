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
        Accepted,
        Cancelled,
        Rejected
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
    ) external onlyOwner {
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

    function placeBid(uint256 _petId) external payable {
        Auction storage auction = petIdToAuction[_petId];
        require(auction.petId != 0, "Auction does not exist");
        require(msg.sender != address(0), "Invalid sender address");
        require(auction.isActive, "Auction is not active");
        require(
            petIdToPets[_petId].isAdopted == false,
            "Pet is already adopted"
        );
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
            require(success, "Failed to refund previous highest bidder");
        }

        //Re-enter Bid if user has cancelled previous bid

        // require(
        //     petIdToUserBids[_petId][msg.sender].length == 0,
        //     "You have already bid on this pet"
        // );

        // Check if the user has any open bids for this pet. Allow user to re-enter bid if they have cancelled previous bid
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

        //Generate a unique bid ID for the user
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

        //Increment total bids
        totalBids++;

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit BidPlaced(_petId, msg.sender, msg.value);
    }

    function cancelBid(uint256 _petId, uint256 _bidId) external {
        require(msg.sender != address(0), "Invalid sender address");
        require(petIdToAuction[_petId].isActive, "Auction is not active");
        require(
            petIdToUserBids[_petId][msg.sender].length > 0,
            "You have not bid on this pet"
        );
        require(
            petIdToUserBids[_petId][msg.sender][_bidId].bid_status ==
                BidStatus.Open,
            "Your bid is not open"
        );

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
        require(success, "Failed to refund previous highest bidder");

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

            // Update the bid status to accepted
            Bid storage bid = petIdToUserBids[_petId][auction.highestBidder][
                _bidId
            ];
            auction.isActive = false;
            bid.bid_status = BidStatus.Accepted;
            userToBids[auction.highestBidder][_bidId].bid_status = BidStatus.Accepted;

            // Set other bids to rejected
            for (uint256 i = 0; i < petIdToBids[_petId].length; i++) {
                Bid storage petBid = petIdToBids[_petId][i];
                Bid storage UserPet = userToBids[auction.highestBidder][i];
                if (
                    petBid.bidder != auction.highestBidder &&
                    petBid.bid_status == BidStatus.Open
                ) {
                    petBid.bid_status = BidStatus.Rejected;
                    UserPet.bid_status = BidStatus.Rejected;
                }
            }

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

    //For Pet Lovers
    function getUnadoptedPets() external view returns (Pet[] memory) {
        Pet[] memory _petListings = new Pet[](petId);
        uint256 count = 0;
        for (uint256 i = 0; i < petId; i++) {
            if (petIdToPets[i + 1].isAdopted == false) {
                _petListings[count] = petIdToPets[i + 1];
                count++;
            }
        }
        return _petListings;
    }

    function getAdoptedPets() external view returns (Pet[] memory) {
        Pet[] memory _petListings = new Pet[](petId);
        uint256 count = 0;
        for (uint256 i = 0; i < petId; i++) {
            if (petIdToPets[i + 1].isAdopted == true) {
                _petListings[count] = petIdToPets[i + 1];
                count++;
            }
        }
        return _petListings;
    }

    function getPetListing(uint256 _petId) external view returns (Pet memory) {
        return petIdToPets[_petId];
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

    function getUserOpenBids(
        address _user
    ) external view returns (Bid[] memory) {
        uint256 openBidsCount = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Open) {
                openBidsCount++;
            }
        }

        Bid[] memory _openBids = new Bid[](openBidsCount);

        uint256 index = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Open) {
                _openBids[index] = userToBids[_user][i];
                index++;
            }
        }

        return _openBids;
    }

    function getUserCancelledBids(
        address _user
    ) external view returns (Bid[] memory) {
        uint256 cancelledBidsCount = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Cancelled) {
                cancelledBidsCount++;
            }
        }

        Bid[] memory _cancelledBids = new Bid[](cancelledBidsCount);

        uint256 index = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Cancelled) {
                _cancelledBids[index] = userToBids[_user][i];
                index++;
            }
        }

        return _cancelledBids;
    }

    function getUserRejectedBids(
        address _user
    ) external view returns (Bid[] memory) {
        uint256 rejectedBidsCount = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Rejected) {
                rejectedBidsCount++;
            }
        }

        Bid[] memory _rejectedBids = new Bid[](rejectedBidsCount);

        uint256 index = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Rejected) {
                _rejectedBids[index] = userToBids[_user][i];
                index++;
            }
        }

        return _rejectedBids;
    }

    function getUserAcceptedBids(
        address _user
    ) external view returns (Bid[] memory) {
        uint256 acceptedBidsCount = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Accepted) {
                acceptedBidsCount++;
            }
        }

        Bid[] memory _acceptedBids = new Bid[](acceptedBidsCount);

        uint256 index = 0;
        for (uint256 i = 0; i < userToBids[_user].length; i++) {
            if (userToBids[_user][i].bid_status == BidStatus.Accepted) {
                _acceptedBids[index] = userToBids[_user][i];
                index++;
            }
        }

        return _acceptedBids;
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