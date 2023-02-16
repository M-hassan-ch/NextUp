const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NextUp", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployAthlete20Contract() {
    const raw = await ethers.getContractFactory("AthleteERC20");
    const contract = await raw.deploy("Athlete1", "ath1");

    return contract;
  }

  async function deployNextUpContract() {
    const raw = await ethers.getContractFactory("NextUp");
    const contract = await raw.deploy("NextUp", "NXT");

    return contract;
  }

  async function deployAthlete721Contract() {
    const raw = await ethers.getContractFactory("AthleteERC721");
    const contract = await raw.deploy("Athlete2", "ath2");

    return contract;
  }

  async function deployAdminContract() {
    const nxtContract = await loadFixture(deployNextUpContract);
    const athleteERC721 = await loadFixture(deployAthlete721Contract);

    const raw = await ethers.getContractFactory("Admin");
    const adminContract = await raw.deploy(10, 1, nxtContract.address, athleteERC721.address);

    return { adminContract, nxtContract };
  }

  describe("Check Contract Deployment", function () {

    it("Should set the right owner of Athlete ERC20 contract", async function () {
      const contract = await loadFixture(deployAthlete20Contract);
      const currentSigner = await ethers.getSigner();
      expect(await contract.owner()).to.equal(currentSigner.address);
    });

    it("Should set the right owner of NextUp ERC20 contract", async function () {
      const contract = await loadFixture(deployNextUpContract);
      const currentSigner = await ethers.getSigner();
      expect(await contract.owner()).to.equal(currentSigner.address);
    });

    it("Should set the right owner of admin contract", async function () {

      const { adminContract, } = await loadFixture(deployAdminContract);
      const currentSigner = await ethers.getSigner();
      expect(await adminContract.owner()).to.equal(currentSigner.address);
    });

    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  describe("Check NextUp ERC20 functionalities", function () {

    describe('Buying NXT', () => {
      it("Should not allow user to buy tokens more than available tokens", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(15, { value: 1 })).to.be.revertedWith(
          "Admin: Dont have enough tokens"
        );
      });

      it("Should not allow user to buy tokens if all available tokens are supplied", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);
        await adminContract.connect(otherSigners).buyNxtTokenInWei(10, { value: 10 });

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 1 })).to.be.revertedWith(
          "Admin: Max supply limit reached"
        );
      });

      it("Should not allow user to buy tokens having insufficient balance", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 7 })).to.be.revertedWith(
          "Admin: Insufficient balance"
        );
      });

      it("Should allow user to buy avallable tokens having sufficient balance", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 8 })).to.changeTokenBalance(
          nxtContract,
          signer,
          8
        );
      });

      it("Should safely transfer ethers from user wallet to contract address", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 8 })
        ).to.changeEtherBalances([signer, adminContract], [-8, 8]);
      });
    });

    describe('NXT contract security', () => {
      it("Should not allow anyone to make changes on NXT contract if reference to admin contract is null", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();
        const owner = await adminContract.owner();
        console.log(owner);
        await expect(nxtContract.connect(signer).mint(otherSigners.address, 10, adminContract.address)).to.be.revertedWith(
          "NextUp: Admin contract address is null"
        );
      });

      it("Should not allow anyone except admin to set reference to admin contract", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await expect(nxtContract.connect(otherSigners).setAdminContract(adminContract.address)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });

      it("Should not allow users other than admin to change refererence to NXT contract in admin smart contract", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        const testaddress = '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199';

        await expect(adminContract.connect(otherSigners).setNextUpERC20Contract(testaddress)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );

      });

      it("Should allow admin to set reference to admin contract", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.connect(signer).setAdminContract(adminContract.address);

        expect(await nxtContract._adminContract()).to.equal(adminContract.address);
      });

      it("Should allow only admin account and admin contract to make changes on NXT contract", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(nxtContract.connect(otherSigners).mint(otherSigners.address, 10, adminContract.address)).to.be.revertedWith(
          "NextUp: Caller is not authorized"
        );

      });

      it("Should allow only admin to change refererence to NXT contract in admin smart contract", async function () {
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        const [signer, otherSigners] = await ethers.getSigners();

        const testaddress = '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199';
        await adminContract.setNextUpERC20Contract(testaddress);

        expect(await adminContract._nextUpContract()).to.equal(testaddress);

      });
    });

  });

  describe('Check Athlete ERC20 functionalities', function () {

    describe('Check Creating an athlete functionality', () => {
      it("Should allow only admin to create an athlete", async function () {

        // const { adminContract, nxtContract } = await loadFixture(deployAdminContract);
        // const athleteContract = await loadFixture(deployAthlete20Contract);

        const [signer, otherSigners] = await ethers.getSigners();
        let AthleteERC20Details = {
          price: 2,
          contractAddress: signer.address,
          isDisabled: false,
          maxSupply: 10,
          suppliedAmount: 0,
          availableForSale: 0,
          countMaxSupplyAsAvailableTokens: false,
        }
        // const owner = await adminContract._nxtPrice();
        const { adminContract, nxtContract } = await loadFixture(deployAdminContract);

        // const [signer, otherSigners] = await ethers.getSigners();
        const owner = await adminContract.owner();
        
        console.log(owner, signer.address)
        // {timestamp:123,supply:10, price:2}
        const drops = [];
        // console.log("asdadasas");
        
        const tx = await adminContract.createAthleteToken(AthleteERC20Details, drops)
        const result = await tx.wait();
        
        if (result){
          console.log(result.events[0].args);
        }
        // for (const event of result.events) {
        //   console.log(`Event ${event.event} with args ${event.args}`);
        // }

        // for (const event of result.events) {
        //   console.log(`Event ${event.event} with args ${event.args}`);
        // }

        // await expect(adminContract.createAthleteReward(signer.address, 0, '123',10)).to.be.revertedWith(
        //   "Admin: Athlete account not found"
        // );

        // await expect(tx)
        // .to.emit(adminContract, 'AthleteTokenCreated')
        // .withArgs(signer.address, 1);
        
        // const result = await expect(adminContract.createAthleteToken(AthleteERC20Details, drops))
        // .to.emit(adminContract, 'AthleteTokenCreated')
        // .withArgs(signer.address, 1);
        // await result.wait();
        // console.log(result);

      })
    });
  });

});
