// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./AthleteERC20.sol";
import "./NextUp.sol";

contract Admin is Ownable, Pausable {
    // -------------------------- Managing Athlete --------------------------
    struct Drop {
        uint256 timestamp;
        uint256 supply;
        uint256 price;
    }

    struct AthleteERC20Details {
        uint256 price; // Here price of AthleteERC20 token is in NextUp tokens
        address contractAddress;
        bool isDisabled;
        uint256 maxSupply;
        uint256 suppliedAmount;
        uint256 availableForSale;
        bool countMaxSupplyAsAvailableTokens;
    }

    uint256 public _nxtMaxSupply;
    uint256 public _nxtSuppliedAmount;
    // uint public _pricePerNxtTokenInFiat;
    uint256 public _nxtPrice;

    uint256 _athleteId;

    AthleteERC20 _athleteContract;
    Admin _self;
    NextUp public _nextUpContract;

    //  mapping(Athelete => Athlete ERC20 token details)
    mapping(uint256 => AthleteERC20Details) public _athleteERC20Detail;
    //  mapping(Athelete => Athlete token drops)
    mapping(uint256 => Drop[]) public _athleteDrops;

    constructor(
        uint256 maxSupply,
        uint256 priceInwei,
        address nextUpERC20Contract
    ) {
        require(maxSupply > 0, "Admin: Max supply should be greater than zero");
        require(
            priceInwei > 0,
            "Admin: Price of token should be greater than zero"
        );
        require(
            nextUpERC20Contract != address(0),
            "Admin: Next-Up contract address is null"
        );

        _self = Admin(address(this));
        _nextUpContract = NextUp(nextUpERC20Contract);

        _nxtMaxSupply = maxSupply;
        _nxtPrice = priceInwei;

        // _pricePerNxtTokenInFiat = priceInFiat;
        // approve(address(this), initialMint);
    }

    modifier isValidAthlete(uint256 athleteId) {
        require(
            _athleteERC20Detail[athleteId].contractAddress != address(0),
            "Admin: Athlete account not found"
        );
        _;
    }

    modifier isAthleteNotDisabled(uint256 athleteId) {
        require(
            _athleteERC20Detail[athleteId].isDisabled == false,
            "Admin: Athlete account is disabled"
        );
        _;
    }

    function setNextUpERC20Contract(address nextUpERC20Contract)
        public
        onlyOwner
    {
        require(
            nextUpERC20Contract != address(0),
            "Admin: Next-Up contract address is null"
        );
        _nextUpContract = NextUp(nextUpERC20Contract);
    }

    // -------------------------- User related functions --------------------------

    //  In case, if customer is buying NextUp tokens in WEI
    function buyNxtTokenInWei(uint256 amountToBuy) public payable {
        require(msg.sender != address(0), "Admin: Caller is null address");
        require(
            _nxtSuppliedAmount < _nxtMaxSupply,
            "Admin: Max supply limit reached"
        );
        require(
            amountToBuy <= (_nxtMaxSupply - _nxtSuppliedAmount),
            "Admin: Dont have enough tokens"
        );
        require(
            msg.value == (_nxtPrice * amountToBuy),
            "Admin: Insufficient balance"
        );

        _nxtSuppliedAmount += amountToBuy;
        _nextUpContract.mint(msg.sender, amountToBuy);
        // approve(address(this), amountToBuy);
    }

    //  In case, if customer is buying NextUp tokens with USD (Fiat money)
    // function buyTokenInFiat(uint amountToBuy, address addressTo) public onlyOwner
    // {
    //     require(amountToBuy <= balanceOf(owner()), "Admin: Insufficient owner's balance");
    //     transferFrom(owner(), addressTo, amountToBuy);
    //     // approve(address(this), amountToBuy);
    // }

    //     require(amountToBuy <= balanceOf(owner()), "Admin: Insufficient owner's balance");
    //     transferFrom(owner()
    // -------------------------- Athlete related functions --------------------------

    //  Delete an athlete profile is missing
    //  Before calling this function admin has already deployed AthleteERC20 contract
    //  ERC20 token name and symbol already had given during the deployement
    //  Creating an athlete with drops(sorted array). This function returns id of created athlete
    function createAthlete(
        AthleteERC20Details memory athleteDetails,
        Drop[] memory tokenDrops
    ) public onlyOwner returns (uint256) {
        require(
            isValidAthleteDetails(athleteDetails),
            "Admin: Invalid athlete details"
        );

        _athleteId++;

        _athleteERC20Detail[_athleteId] = athleteDetails;

        if (tokenDrops.length == 0) {
            // _athleteERC20Detail[_athleteId].availableForSale = _athleteERC20Detail[_athleteId].maxSupply;
            _athleteERC20Detail[_athleteId]
                .countMaxSupplyAsAvailableTokens = true;
        } else {
            require(
                isValidDrop(_athleteId, tokenDrops),
                "Admin: Got an invalid token drop"
            );
            for (uint256 i = 0; i < tokenDrops.length; i++) {
                _athleteDrops[_athleteId].push(tokenDrops[i]);
            }
            // availableForSale token will set when we run applyDrop() of athlete
        }

        _athleteContract = AthleteERC20(_athleteERC20Detail[_athleteId].contractAddress);
        _athleteContract.approve(address(this),  _athleteERC20Detail[_athleteId].maxSupply);

        return _athleteId;
    }

    function buyAthleteTokens(uint256 athleteId, uint256 amountToBuy)
        public
        isValidAthlete(athleteId)
        isAthleteNotDisabled(athleteId)
    {
        require(amountToBuy > 0, "Admin: Amount should be greater than zero");
        require(
            _athleteERC20Detail[athleteId].suppliedAmount <
                _athleteERC20Detail[athleteId].maxSupply,
            "Admin: Max supply limit reached"
        );
        require(
            amountToBuy <= getAthleteAvailableForSaleTokens(athleteId),
            "Admin: Athlete Dont have enough available tokens"
        );
        require(
            getUserNxtBalance() >=
                (_athleteERC20Detail[athleteId].price * amountToBuy),
            "Admin: Insufficient NXT Tokens to buy athlete tokens"
        );
        // require(amountToBuy <= (_nxtMaxSupply - _nxtSuppliedAmount), "Admin: Admin dont have enough nextUp tokens");

        _athleteERC20Detail[athleteId].suppliedAmount += amountToBuy;
        
        if (!_athleteERC20Detail[athleteId].countMaxSupplyAsAvailableTokens) {
            _athleteERC20Detail[athleteId].availableForSale -= amountToBuy;
        }

        _nextUpContract.transferFrom(msg.sender, owner(), (_athleteERC20Detail[athleteId].price * amountToBuy));
        
        _athleteContract = AthleteERC20(_athleteERC20Detail[athleteId].contractAddress);
        _athleteContract.mint(msg.sender, amountToBuy);

    }

    function addAthleteDrops(uint256 athleteId, Drop[] memory tokenDrops)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        require(
            isValidDrop(athleteId, tokenDrops),
            "Admin: Got an invalid token drop"
        );

        _athleteERC20Detail[_athleteId].countMaxSupplyAsAvailableTokens = false;

        for (uint256 i = 0; i < tokenDrops.length; i++) {
            _athleteDrops[_athleteId].push(tokenDrops[i]);
        }
    }

    function applyAthleteDrop(uint256 athleteId)
        public
        isValidAthlete(athleteId)
        returns (bool, Drop memory)
    {
        require(
            _athleteDrops[athleteId].length > 0,
            "Admin: Athlete token don't have drops"
        );

        Drop memory drop;

        for (uint256 i = 0; i < _athleteDrops[athleteId].length; i++) {
           
            if (block.timestamp >= _athleteDrops[athleteId][i].timestamp) {
                
                _athleteERC20Detail[athleteId].availableForSale += _athleteDrops[athleteId][i].supply;
                _athleteERC20Detail[athleteId].price = _athleteDrops[athleteId][i].price;
                
                drop = _athleteDrops[athleteId][i];
                deleteTokenDrop(athleteId, i);
                
                return (true, drop);
            }
        }

        return (false, drop);
    }

    function updateAthleteERC20MaxSupply(uint athleteId, uint supply) public onlyOwner isValidAthlete(athleteId){
        require(supply > 0, "Admin: Amount is zero");
        _athleteERC20Detail[athleteId].maxSupply += supply;

        _athleteContract = AthleteERC20(_athleteERC20Detail[_athleteId].contractAddress);
        _athleteContract.increaseAllowance(address(this),  _athleteERC20Detail[_athleteId].maxSupply);
    }

    //  Admin call this function to update the price(In NXT tokens) of Athlete's ERC20 Token
    function updateAthleteTokenPrice(uint256 athleteId, uint256 price)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        _athleteERC20Detail[athleteId].price = price;
    }

    //  Admin call this function to increase the max supply of Athlete's ERC20 Token
    function increaseAthleteTokenMaxSupply(uint256 athleteId, uint256 addSupply)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        require(
            addSupply > 0,
            "Admin: Amount of supply you wanted to increase should be greater than zero"
        );
        _athleteERC20Detail[athleteId].maxSupply += addSupply;
    }

    function updateAthleteStatus(bool status, uint256 athleteId)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        _athleteERC20Detail[athleteId].isDisabled = status;
    }

    function increaseNxtTokenMaxSupply(uint256 updatedSupply) public onlyOwner {
        require(
            updatedSupply > 0,
            "Admin: Updated supply should be greater than zero"
        );
        _nxtMaxSupply += updatedSupply;
    }

    function transferBalance() public onlyOwner {
        require(address(this).balance > 0, "Conract has zero balance");
        payable(owner()).transfer(address(this).balance);
    }

    function updateNxtTokenPrice(uint256 updatedPrice) public onlyOwner {
        _nxtPrice = updatedPrice;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    //    --------------------------- View Functions ---------------------------

    function getAthleteAvailableForSaleTokens(uint256 athleteId)
        public
        view
        isValidAthlete(athleteId)
        returns (uint256)
    {
        if (_athleteERC20Detail[athleteId].countMaxSupplyAsAvailableTokens) {
            return (_athleteERC20Detail[athleteId].maxSupply -
                _athleteERC20Detail[athleteId].suppliedAmount);
        } else {
            return _athleteERC20Detail[athleteId].availableForSale;
        }
    }

    //  Get all the token drops asociated with an athlete
    function getTokenDrops(uint256 athleteId)
        public
        view
        isValidAthlete(athleteId)
        returns (Drop[] memory)
    {
        return _athleteDrops[athleteId];
    }

    function getUserNxtBalance() public view returns (uint256) {
        return _nextUpContract.balanceOf(msg.sender);
    }

    //   --------------------------- Internal Functions ---------------------------

    function isValidDrop(uint256 athleteId, Drop[] memory drops)
        internal
        view
        returns (bool)
    {
        uint256 currentTime = block.timestamp;
        uint256 totalSupply = getAthleteTotalSupplyInDrops(athleteId);

        for (uint256 i = 0; i < drops.length; i++) {
            if (
                (drops[i].timestamp < currentTime) ||
                drops[i].price <= 0 ||
                drops[i].supply <= 0
            ) {
                return false;
            } else {
                totalSupply += drops[i].supply;
            }
        }

        if (
            totalSupply >
            (_athleteERC20Detail[athleteId].maxSupply -
                _athleteERC20Detail[athleteId].suppliedAmount)
        ) {
            return false;
        }

        return true;
    }

    function getAthleteTotalSupplyInDrops(uint256 athleteId)
        internal
        view
        returns (uint256)
    {
        uint256 totalSupply;

        for (uint256 i = 0; i < _athleteDrops[athleteId].length; i++) {
            totalSupply += _athleteDrops[athleteId][i].supply;
        }

        return totalSupply;
    }

    function isValidAthleteDetails(AthleteERC20Details memory athleteDetails)
        internal
        pure
        returns (bool)
    {
        if (
            !(athleteDetails.price > 0 ||
                athleteDetails.contractAddress != address(0) ||
                athleteDetails.isDisabled == false ||
                athleteDetails.maxSupply > 0 ||
                athleteDetails.suppliedAmount == 0 ||
                athleteDetails.availableForSale == 0 ||
                athleteDetails.countMaxSupplyAsAvailableTokens == false)
        ) {
            return false;
        }
        return true;
    }

    function deleteTokenDrop(uint256 athleteId, uint256 index) internal {
        _athleteDrops[athleteId][index] = _athleteDrops[athleteId][
            _athleteDrops[athleteId].length - 1
        ];
        _athleteDrops[athleteId].pop();
    }
}
