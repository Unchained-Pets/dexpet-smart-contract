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
    const [owner, account1] = await hre.ethers.getSigners();

    const DexPet = await hre.ethers.getContractFactory("DexPet");
    const dexPet = await DexPet.deploy();

    return { dexPet, owner, account1 };
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

      expect(await dexPet.petId()).equal(1);
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

      await dexPet.listPetForAuction(petId,startingPrice,duration);
      expect(await dexPet.getPetListing(petId))
    });
  });
});
