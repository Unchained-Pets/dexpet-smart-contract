// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


library Errors {
    error OnlyOwner();
    error ZeroAddressError();
    error PetAlreadyAdopted();
    error DurationCannotBeZero();
    error InvalidAuction();
    error AuctionNotActive();
    error AuctionHasEnded();
    error AuctionIsActive();
    error PrevBidderRefundFailed();
    error BidTooLow();
    error PetIsInOpenBid();
    error NoActivePetBid();
    error YourBidIsNotOpen();
    

    error StartPriceMustBeZero();
}   

library Events {
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
        uint8 category
    );
    event BidCancelled(uint256 indexed petId, address bidder, uint256 amount);
    event AuctionCreated(
        uint256 indexed petId,
        uint256 startingPrice,
        uint256 endTime
    );
}