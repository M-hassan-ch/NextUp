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

  async function deployAdminContract() {
    const nxtContract = await loadFixture(deployNextUpContract);

    const raw = await ethers.getContractFactory("Admin");
    const adminContract = await raw.deploy(10, 1, nxtContract.address);

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

    describe('NXT contract security', () => {
      it("Should allow only admin account and admin contract to make changes on NXT contract", async function () {
        
        
      });
    });

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


    // it("Should fail if the unlockTime is not in the future", async function () {
    //   // We don't use the fixture here because we want a different deployment
    //   const latestTime = await time.latest();
    //   const Lock = await ethers.getContractFactory("Lock");
    //   await expect(Lock.deploy(latestTime, { value: 1 })).to.be.revertedWith(
    //     "Unlock time should be in the future"
    //   );
    // });
  });

  // describe("Withdrawals", function () {
  //   describe("Validations", function () {
  //     it("Should revert with the right error if called too soon", async function () {
  //       const { lock } = await loadFixture(deployAthlete20Contract);

  //       await expect(lock.withdraw()).to.be.revertedWith(
  //         "You can't withdraw yet"
  //       );
  //     });

  //     it("Should revert with the right error if called from another account", async function () {
  //       const { lock, unlockTime, otherAccount } = await loadFixture(
  //         deployAthlete20Contract
  //       );

  //       // We can increase the time in Hardhat Network
  //       await time.increaseTo(unlockTime);

  //       // We use lock.connect() to send a transaction from another account
  //       await expect(lock.connect(otherAccount).withdraw()).to.be.revertedWith(
  //         "You aren't the owner"
  //       );
  //     });

  //     it("Shouldn't fail if the unlockTime has arrived and the owner calls it", async function () {
  //       const { lock, unlockTime } = await loadFixture(
  //         deployAthlete20Contract
  //       );

  //       // Transactions are sent using the first currentSigner by default
  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).not.to.be.reverted;
  //     });
  //   });

  //   describe("Events", function () {
  //     it("Should emit an event on withdrawals", async function () {
  //       const { lock, unlockTime, lockedAmount } = await loadFixture(
  //         deployAthlete20Contract
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw())
  //         .to.emit(lock, "Withdrawal")
  //         .withArgs(lockedAmount, anyValue); // We accept any value as `when` arg
  //     });
  //   });

  //   describe("Transfers", function () {
  //     it("Should transfer the funds to the owner", async function () {
  //       const { lock, unlockTime, lockedAmount, owner } = await loadFixture(
  //         deployAthlete20Contract
  //       );

  //       await time.increaseTo(unlockTime);

  //       await expect(lock.withdraw()).to.changeEtherBalances(
  //         [owner, lock],
  //         [lockedAmount, -lockedAmount]
  //       );
  //     });
  //   });
  // });

});
