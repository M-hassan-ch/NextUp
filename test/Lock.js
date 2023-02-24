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

    return adminContract;
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

      const adminContract = await loadFixture(deployAdminContract);
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

    let nxtContract;
    let adminContract;

    describe('Buying NXT', () => {

      beforeEach(async function () {
        adminContract = await loadFixture(deployAdminContract);
        const nxtContractAddr = await adminContract._nextUpContract();

        let raw = await ethers.getContractFactory("NextUp");
        nxtContract = await raw.attach(nxtContractAddr);
      });

      it("Should not allow user to buy tokens more than available tokens", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(15, { value: 1 })).to.be.revertedWith(
          "Admin: Dont have enough tokens"
        );
      });

      it("Should not allow user to buy tokens if all available tokens are supplied", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);
        await adminContract.connect(otherSigners).buyNxtTokenInWei(10, { value: 10 });

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 1 })).to.be.revertedWith(
          "Admin: Max supply limit reached"
        );
      });

      it("Should not allow user to buy tokens having insufficient balance", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 7 })).to.be.revertedWith(
          "Admin: Insufficient balance"
        );
      });

      it("Should allow user to buy avallable tokens having sufficient balance", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 8 })).to.changeTokenBalance(
          nxtContract,
          signer,
          8
        );
      });

      it("Should safely transfer ethers from user wallet to contract address", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(adminContract.connect(signer).buyNxtTokenInWei(8, { value: 8 })
        ).to.changeEtherBalances([signer, adminContract], [-8, 8]);
      });
    });

    describe('NXT contract security', () => {
      beforeEach(async function () {
        adminContract = await loadFixture(deployAdminContract);
        const nxtContractAddr = await adminContract._nextUpContract();
        const athleteERC721Addr = await adminContract._athleteERC721Contract();

        let raw = await ethers.getContractFactory("NextUp");
        nxtContract = await raw.attach(nxtContractAddr);
        raw = await ethers.getContractFactory("AthleteERC721");
        athleteERC721Contract = await raw.attach(athleteERC721Addr);
      });

      it("Should not allow anyone to make changes on NXT contract if reference to admin contract is null", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await expect(nxtContract.connect(signer).mint(otherSigners.address, 10, adminContract.address)).to.be.revertedWith(
          "NextUp: Admin contract address is null"
        );
      });

      it("Should not allow anyone except admin to set reference to admin contract", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await expect(nxtContract.connect(otherSigners).setAdminContract(adminContract.address)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );
      });

      it("Should not allow users other than admin to change refererence to NXT contract in admin smart contract", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        const testaddress = '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199';

        await expect(adminContract.connect(otherSigners).setNextUpERC20Contract(testaddress)).to.be.revertedWith(
          "Ownable: caller is not the owner"
        );

      });

      it("Should allow admin to set reference to admin contract", async function () {

        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.connect(signer).setAdminContract(adminContract.address);

        expect(await nxtContract._adminContract()).to.equal(adminContract.address);
      });

      it("Should allow only admin account and admin contract to make changes on NXT contract", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        await nxtContract.setAdminContract(adminContract.address);

        await expect(nxtContract.connect(otherSigners).mint(otherSigners.address, 10, adminContract.address)).to.be.revertedWith(
          "NextUp: Caller is not authorized"
        );

      });

      it("Should allow only admin to change refererence to NXT contract in admin smart contract", async function () {

        const [signer, otherSigners] = await ethers.getSigners();

        const testaddress = '0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199';
        await adminContract.setNextUpERC20Contract(testaddress);

        expect(await adminContract._nextUpContract()).to.equal(testaddress);

      });
    });

  });

  describe('Check Athlete ERC20 functionalities (without drops)', function () {

    describe('Check create an athlete token functionality', () => {
      it("Should allow only admin to create an athlete", async function () {

        const [signer, otherSigners] = await ethers.getSigners();
        const AthleteERC20Contract = await loadFixture(deployAthlete20Contract);
        let AthleteERC20Details = {
          price: 2,
          contractAddress: AthleteERC20Contract.address,
          isDisabled: false,
          maxSupply: 10,
          suppliedAmount: 0,
          availableForSale: 0,
          countMaxSupplyAsAvailableTokens: false,
        }

        const adminContract = await loadFixture(deployAdminContract);

        // {timestamp:123,supply:10, price:2}
        const drops = [];

        await expect(adminContract.createAthleteToken(AthleteERC20Details, drops))
          .to.emit(adminContract, 'AthleteTokenCreated')
          .withArgs(AthleteERC20Contract.address, 1);

        // const tx = await adminContract.createAthleteToken(AthleteERC20Details, drops)
        // const result = await tx.wait();

        // if (result){
        //   console.log(result.events[0].args);
        // }

      })

      it("Should not allow any user except admin to create an athlete token", async function () {
        const [signer, otherSigners] = await ethers.getSigners();
        const AthleteERC20Contract = await loadFixture(deployAthlete20Contract);
        let AthleteERC20Details = {
          price: 2,
          contractAddress: AthleteERC20Contract.address,
          isDisabled: false,
          maxSupply: 10,
          suppliedAmount: 0,
          availableForSale: 0,
          countMaxSupplyAsAvailableTokens: false,
        }

        const adminContract = await loadFixture(deployAdminContract);

        // {timestamp:123,supply:10, price:2}
        const drops = [];


        await expect(adminContract.connect(otherSigners).createAthleteToken(AthleteERC20Details, drops)).to.be.revertedWith("Ownable: caller is not the owner");

      })

      // it("Should not allow only admin to create an athlete with valid athlete details", async function () {
      //   const [signer, otherSigners] = await ethers.getSigners();
      //   const AthleteERC20Contract = await loadFixture(deployAthlete20Contract);

      //   let AthleteERC20Details = {
      //     price: 0,
      //     contractAddress: AthleteERC20Contract.address,
      //     isDisabled: true,
      //     maxSupply: 10,
      //     suppliedAmount: 0,
      //     availableForSale: 0,
      //     countMaxSupplyAsAvailableTokens: false,
      //   }

      //   const adminContract = await loadFixture(deployAdminContract);

      //   // {timestamp:123,supply:10, price:2}
      //   const drops = [];
      //   const tx = await adminContract.createAthleteToken(AthleteERC20Details, drops);
      //   const res =tx
      //   console.log(AthleteERC20Details.price);
      //   await expect(adminContract.createAthleteToken(AthleteERC20Details, drops)).to.be.revertedWith("Admin: Invalid athlete details");
      // })


    });
  });

  describe('Check Athlete ERC721 functionalities', function () {
    let adminContract;
    let athleteERC721Contract;
    
    describe('Check create an athlete reward functionality', () => {
      
      beforeEach(async function () {
        adminContract = await loadFixture(deployAdminContract);
        const athleteERC721Addr = await adminContract._athleteERC721Contract();

        let raw = await ethers.getContractFactory("AthleteERC721");
        athleteERC721Contract = await raw.attach(athleteERC721Addr);
      });

      it("Should not allow any user except admin to create an athlete reward", async function () {
        const [signer, otherSigners] = await ethers.getSigners();

        const athleteERC20Contract = await loadFixture(deployAthlete20Contract);
  
        let AthleteERC20Details = {
          price: 2,
          contractAddress: athleteERC20Contract.address,
          isDisabled: false,
          maxSupply: 10,
          suppliedAmount: 0,
          availableForSale: 0,
          countMaxSupplyAsAvailableTokens: false,
        }


        let tx = await adminContract.createAthleteToken(AthleteERC20Details, []);
        let result = await tx.wait();
       
        // let temp = await adminContract.connect(otherSigners);
        // console.log('updated signer');
        
        const tx1 = await adminContract.createAthleteReward('0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199', 1, 'zyx', 123);
        const res1 = await tx1.wait();
        console.log(res1);

        await expect(adminContract.createAthleteReward('0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199', 1, 'zyx', 123))
          .to.emit(adminContract, 'AthleteRewardCreated')
          .withArgs(1, 1);
        // result = await tx.wait();
        // console.log(result);
        // await expect(adminContract.connect(otherSigners).createAthleteReward(otherSigners.address, '1', 'qweer', '123')).to.be.revertedWith("Ownable: caller is not the owner");
      })
    });
  });

});
