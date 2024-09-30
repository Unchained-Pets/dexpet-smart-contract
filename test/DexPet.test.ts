import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";

describe("DexPet", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployDexPet() {
    // Contracts are deployed using the first signer/account by default
    const [owner, account1, account2] = await hre.ethers.getSigners();

    const DexPet = await hre.ethers.getContractFactory("DexPet");
    const dexPet = await DexPet.deploy();

    return { dexPet, owner, account1, account2 };
  }

  describe("Deployment", function () {
    it("Should set the owner", async function () {
      const { dexPet, owner } = await loadFixture(deployDexPet);

      expect(await dexPet.owner()).to.equal(owner);
    });
    it("Should set the default states", async function () {
      const { dexPet, owner } = await loadFixture(deployDexPet);

      expect(await dexPet.petId()).to.equal(0);
      expect(await dexPet.totalBids()).to.equal(0);
    });
  });
  describe("Add Pet", function () {
    it("Should revert if called by non owner", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      await expect(
        dexPet
          .connect(account1)
          .addPet(
            name,
            breed,
            color,
            price,
            picture,
            yearOfBirth,
            description,
            category
          )
      ).to.be.revertedWithCustomError(dexPet, "OnlyOwner");
    });
    it("Should add Pets successfully", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      await expect(
        dexPet.addPet(
          name,
          breed,
          color,
          price,
          picture,
          yearOfBirth,
          description,
          category
        )
      )
        .to.emit(dexPet, "PetAdded")
        .withArgs(
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

      expect((await dexPet.getPet(petId)).name).equal(name);
    });
  });
  describe("List Pet for Aunction", function () {
    it("Should revert if called by non owner", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );
      const petId = 1;
      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;
      await expect(
        dexPet
          .connect(account1)
          .listPetForAuction(petId, startingPrice, duration)
      ).to.be.revertedWithCustomError(dexPet, "OnlyOwner");
    });
    it("Should list a Pet successfully", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      const auction = await dexPet.getPetAuction(petId);
      expect(auction.petId).to.equal(petId);
      expect(auction.startingPrice).to.equal(startingPrice);
    });
    it("Should now allow owner list a pet multiple times", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      await expect(
        dexPet.listPetForAuction(petId, startingPrice, duration)
      ).to.be.revertedWithCustomError(dexPet, "PetIsInOpenBid");
    });
    it("Should create and list multiple Pet successfully", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      const name2 = "kitty";
      const breed2 = 1;
      const color2 = "orange";
      const price2 = 1000;
      const picture2 = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth2 = 2019;
      const description2 = "a lovely cat";
      const category2 = 1;
      petId = 2;
      // add pet
      await dexPet.addPet(
        name2,
        breed2,
        color2,
        price2,
        picture2,
        yearOfBirth2,
        description2,
        category2
      );

      const startingPrice2 = ethers.parseEther("500");
      const duration2 = 2000000000000;

      await dexPet.listPetForAuction(petId, startingPrice2, duration2);
    });
  });
  describe("End Pet Aunction", function () {
    it("Should revert if aunction is not active", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;
      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      // await dexPet.listPetForAuction(petId, startingPrice, duration);

      await expect(dexPet.endAuction(petId)).to.be.revertedWithCustomError(
        dexPet,
        "AuctionNotActive"
      );
    });
    it("Should revert if aunction endtime is not reached", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;
      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      await expect(dexPet.endAuction(petId)).to.be.revertedWithCustomError(
        dexPet,
        "AuctionIsActive"
      );
    });
    it("Should end auction successfully when endtime is reached and no bidding", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;
      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);
      const block = await ethers.provider.getBlock("latest");
      const timestamp = block!.timestamp;

      time.increaseTo(timestamp + duration);

      await expect(dexPet.endAuction(petId))
        .to.emit(dexPet, "AuctionEnded")
        .withArgs(petId, ethers.ZeroAddress, 0);
    });
    // 1 test: should end auction when there are bids
  });
  describe("Place bid", function () {
    it("Should revert if auction time is ended", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      const block = await ethers.provider.getBlock("latest");
      const timestamp = block!.timestamp;
      time.increaseTo(timestamp + duration);

      await expect(
        dexPet.connect(account1).placeBid(petId)
      ).to.be.revertedWithCustomError(dexPet, "AuctionHasEnded");
    });
    it("Should revert if user passes in a smaller bid", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      await expect(
        dexPet.connect(account1).placeBid(petId)
      ).to.be.revertedWithCustomError(dexPet, "BidTooLow");
    });
    it("Should place bid successfully", async function () {
      const { dexPet, account1 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      const amount = ethers.parseEther("200");

      const bidderBalBefore = await ethers.provider.getBalance(account1);

      await expect(dexPet.connect(account1).placeBid(petId, { value: amount }))
        .to.emit(dexPet, "BidPlaced")
        .withArgs(petId, account1, amount);

      expect(await ethers.provider.getBalance(account1)).to.be.lessThan(
        bidderBalBefore
      );
    });
    it("Should place multiple bids successfully successfully", async function () {
      const { dexPet, account1, account2 } = await loadFixture(deployDexPet);
      const name = "kitty";
      const breed = 1;
      const color = "orange";
      const price = 1000;
      const picture = "ejhnasdjlae9iwenjhkbbfwe";
      const yearOfBirth = 2019;
      const description = "a lovely cat";
      const category = 1;

      let petId = 1;
      // add pet
      await dexPet.addPet(
        name,
        breed,
        color,
        price,
        picture,
        yearOfBirth,
        description,
        category
      );

      const startingPrice = ethers.parseEther("100");
      const duration = 1000000000000;

      await dexPet.listPetForAuction(petId, startingPrice, duration);

      let amount = ethers.parseEther("200");

      await expect(dexPet.connect(account1).placeBid(petId, { value: amount }))
        .to.emit(dexPet, "BidPlaced")
        .withArgs(petId, account1, amount);

      const prevBidderBalBeforeRejection = await ethers.provider.getBalance(
        account1
      );

      amount = ethers.parseEther("400");

      const newBidderBalBefore = await ethers.provider.getBalance(
        account2
      );

      await expect(dexPet.connect(account2).placeBid(petId, { value: amount }))
        .to.emit(dexPet, "BidPlaced")
        .withArgs(petId, account2, amount);

        // prev bidder should increment, because of the refund
      expect(await ethers.provider.getBalance(account1)).to.be.greaterThan(
        prevBidderBalBeforeRejection
      );

      // new bidder would be debited
      expect(await ethers.provider.getBalance(account2)).to.be.lessThan(
        newBidderBalBefore
      );

    });
  });
});
