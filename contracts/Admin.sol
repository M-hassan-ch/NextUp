// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./AthleteERC20.sol";
import "./NextUp.sol";
import "./AthleteERC721.sol";

contract Admin is Ownable, Pausable {

    event AthleteTokenPkgDeleted(uint indexed athleteTokenPkgId, address seller, uint quantity, uint price, uint athleteId);
    event AthleteTokenPkgCreated(uint indexed athleteTokenPkgId);
    event AthleteTokenCreated(address indexed athleteERC20Addr, uint athleteId);
    event AthleteRewardCreated(uint indexed athleteId, uint tokenId);
    event DropApplied(uint indexed athleteId, Drop appliedDrop);
    
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

    struct AthleteTokenPkg{
        address seller;
        uint quantity;
        uint price;
        uint athleteId;
    }

    uint256 public _nxtMaxSupply;
    uint256 public _nxtSuppliedAmount;
    // uint public _pricePerNxtTokenInFiat;
    uint256 public _nxtPrice;

    uint256 _athleteId;

    AthleteERC20 public _athleteERC20Contract;
    Admin public _self;
    NextUp public _nextUpContract;
    AthleteERC721 public _athleteERC721Contract;

    //  mapping(Athelete => Athlete ERC20 token details)
    mapping(uint256 => AthleteERC20Details) public _athleteERC20Detail;
    //  mapping(Athelete => Athlete token drops)
    mapping(uint256 => Drop[]) public _athleteDrops;

    // -------------------------- NFT -------------------------- 

    // mapping(tokenId => price)
    mapping(uint256 => uint256) public _athleteNftPrice; // Athlete nft price in Athlete token
    // mapping(tokenOwner => tokenIds[])
    using EnumerableSet for EnumerableSet.UintSet;
    mapping(address => EnumerableSet.UintSet) _userBoughtAthNfts;
    // mapping(athleteId => athleteNfts[])
    mapping(uint256 => EnumerableSet.UintSet) _athleteNfts;
    
    // -------------------------- Athlete Token Package --------------------------

    uint public _athleteTokenPkgId;
    mapping(uint => AthleteTokenPkg) public _athleteTokenPkg;
    mapping(address => EnumerableSet.UintSet) _sellersCreatedAthleteTokenpkg;
    EnumerableSet.UintSet _validAthleteTokenpkgIds;


    constructor(
        uint256 maxSupply,
        uint256 priceInwei,
        address nextUpERC20Address,
        address athleteERC721Address
    ) {
        require(
            nextUpERC20Address != address(0),
            "Admin: NXT contract address is null"
        );
        require(
            athleteERC721Address != address(0),
            "Admin: AthleteERC721 contract address is null"
        );
        require(maxSupply > 0, "Admin: Max supply should be greater than zero");
        require(
            priceInwei > 0,
            "Admin: Price of token should be greater than zero"
        );
        require(
            nextUpERC20Address != address(0),
            "Admin: Next-Up contract address is null"
        );

        _nxtMaxSupply = maxSupply;
        _nxtPrice = priceInwei;

        _self = Admin(address(this));
        _nextUpContract = NextUp(nextUpERC20Address);
        _athleteERC721Contract = AthleteERC721(athleteERC721Address);

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

    modifier isNftExists(uint256 tokenId) {
        require(_athleteNftPrice[tokenId] > 0, "Admin: Token id dont exists");
        _;
    }

    modifier isAthleteNotDisabled(uint256 athleteId) {
        require(
            _athleteERC20Detail[athleteId].isDisabled == false,
            "Admin: Athlete account is disabled"
        );
        _;
    }

    function createAthleteTokenPkg(AthleteTokenPkg memory athleteTokenPkg) public isValidAthlete(athleteTokenPkg.athleteId) isAthleteNotDisabled(athleteTokenPkg.athleteId){
        require(athleteTokenPkg.seller != address(0), "Admin: seller is null address");
        require(athleteTokenPkg.quantity>0, "Admin: quaatity is 0");
        require(athleteTokenPkg.price>0, "Admin: price is 0");
        require(athleteTokenPkg.seller == msg.sender, "Admin: Seller and caller is not same");
        require(isEligibleForPkgCreation(athleteTokenPkg.seller, athleteTokenPkg.athleteId, athleteTokenPkg.quantity), "Admin: Insufficient athlete token for package creation");
        
        _athleteTokenPkgId++;
        _athleteTokenPkg[_athleteTokenPkgId] = athleteTokenPkg;
        _sellersCreatedAthleteTokenpkg[athleteTokenPkg.seller].add(_athleteTokenPkgId);
        _validAthleteTokenpkgIds.add(_athleteTokenPkgId);

        emit AthleteTokenPkgCreated(_athleteTokenPkgId);
    }

    function buyAthleteTokenPkg(uint packageId) public isAthleteNotDisabled(_athleteTokenPkg[packageId].athleteId){
        
        AthleteTokenPkg memory package = _athleteTokenPkg[packageId];

        require(package.seller != msg.sender, "Admin: Can't buy own package");
        require(package.seller != address(0), "Admin: Invalid package id");
        require(_nextUpContract.balanceOf(msg.sender) >= package.quantity * package.price, "Admin: Insufficient NXT token for buying package");

        _sellersCreatedAthleteTokenpkg[package.seller].remove(packageId);
        _validAthleteTokenpkgIds.remove(packageId);
        delete _athleteTokenPkg[packageId];

        _athleteERC20Contract = AthleteERC20(
            _athleteERC20Detail[package.athleteId].contractAddress
        );

        _athleteERC20Contract.transferTokens(package.seller, msg.sender,  package.quantity);
        _nextUpContract.transferTokens(msg.sender, package.seller, package.quantity * package.price);

        emit AthleteTokenPkgDeleted(packageId, package.seller, package.quantity, package.price, package.athleteId);
    }

    // -------------------------- User related functions --------------------------

    //  In case, if customer is buying NextUp tokens in WEI
    function buyNxtTokenInWei(uint256 amountToBuy) public payable {
        require(amountToBuy>0, "Admin: amount should not be zero");
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

    //  In case, if customer is buying NextUp tokens in FIAT
    function buyNxtTokenInFiat(address receiver, uint256 amount)
        public
        onlyOwner
    {
        require(receiver != address(0), "Admin: Receiver is null address");
        require(
            _nxtSuppliedAmount < _nxtMaxSupply,
            "Admin: Max supply limit reached"
        );
        require(
            amount <= (_nxtMaxSupply - _nxtSuppliedAmount),
            "Admin: Dont have enough tokens"
        );

        _nxtSuppliedAmount += amount;
        _nextUpContract.mint(receiver, amount);
        // approve(address(this), amountToBuy);
    }

    // -------------------------- Athlete related functions --------------------------

    //  Delete an athlete profile is missing
    //  Before calling this function admin has already deployed AthleteERC20 contract
    //  ERC20 token name and symbol already had given during the deployement
    //  Creating an athlete with drops(sorted array). This function returns id of created athlete
    function createAthleteToken(
        AthleteERC20Details memory athleteDetails,
        Drop[] memory tokenDrops
    ) public onlyOwner {
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

        emit AthleteTokenCreated(_athleteERC20Detail[_athleteId].contractAddress, _athleteId);
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

        _nextUpContract.transferFrom(
            msg.sender,
            owner(),
            (_athleteERC20Detail[athleteId].price * amountToBuy)
        );

        _athleteERC20Contract = AthleteERC20(
            _athleteERC20Detail[athleteId].contractAddress
        );
        _athleteERC20Contract.mint(msg.sender, amountToBuy);
    }


    function createAthleteReward(
        address to,
        uint256 athleteId,
        string memory uri,
        uint256 price
    )
        public
        isValidAthlete(athleteId)
        isAthleteNotDisabled(athleteId)
        onlyOwner
    {
        require(to == owner(), "Admin: Address To is not actual owner");
        require(to != address(0), "Admin: Receiver address is null");
        require(price > 0, "Admin: price of NFT is 0");

        uint256 tokenId = _athleteERC721Contract.safeMint(to, uri);

        _athleteNftPrice[tokenId] = price;

        _userBoughtAthNfts[to].add(tokenId);
        _athleteNfts[athleteId].add(tokenId);

        // its imp to handle the state  when someone sale nft on opensea
        // Solution: verify current nfts ownerships and update states accordingly

        emit AthleteRewardCreated(athleteId, tokenId);
    }

    function buyAthleteReward(uint256 athleteId, uint256 tokenId)
        public
        isValidAthlete(athleteId)
        isAthleteNotDisabled(athleteId)
        isNftExists(tokenId)
    {
        require(msg.sender != address(0), "Admin: Caller is null address");
        require(_userBoughtAthNfts[owner()].contains(tokenId), "Admin: Admin dont have this NFT");
        require(isEligibleForPkgCreation(msg.sender, athleteId, _athleteNftPrice[tokenId]), "Admin: Insufficient athlete tokens (release locked)");

        _athleteERC20Contract = AthleteERC20(
            _athleteERC20Detail[athleteId].contractAddress
        );

        require(
            _athleteERC20Contract.balanceOf(msg.sender) >=
                _athleteNftPrice[tokenId],
            "Admin: Insufficient athlete tokens"
        );

        _userBoughtAthNfts[owner()].remove(tokenId);
        _userBoughtAthNfts[msg.sender].add(tokenId);

        _athleteERC20Contract.transferFrom(
            msg.sender,
            owner(),
            _athleteNftPrice[tokenId]
        );

        _athleteERC721Contract.transferFrom(owner(), msg.sender, tokenId);
    }


//  review add/update feature
    function updateAthleteDrops(uint256 athleteId, Drop[] memory tokenDrops)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        require(
            isValidDrop(athleteId, tokenDrops),
            "Admin: Got an invalid token drop"
        );

        if (_athleteERC20Detail[athleteId].countMaxSupplyAsAvailableTokens) {
            _athleteERC20Detail[athleteId]
                .countMaxSupplyAsAvailableTokens = false;
        }

        for (uint256 i = 0; i < tokenDrops.length; i++) {
            _athleteDrops[athleteId].push(tokenDrops[i]);
        }
    }

//  problem of ascending order array
    function applyAthleteDrop(uint256 athleteId)
        public
        isValidAthlete(athleteId)
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

                emit DropApplied(athleteId, drop);
            }
        }

        emit DropApplied(0, drop);
    }

    function updateAthleteERC20MaxSupply(uint256 athleteId, uint256 addSupply)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        require(addSupply > 0, "Admin: Amount is zero");
        _athleteERC20Detail[athleteId].maxSupply += addSupply;
    }

    //  Admin call this function to update the price(In NXT tokens) of Athlete's ERC20 Token
    function updateAthleteTokenPrice(uint256 athleteId, uint256 price)
        public
        onlyOwner
        isValidAthlete(athleteId)
    {
        _athleteERC20Detail[athleteId].price = price;
    }

    function setNextUpERC20Contract(address nextUpERC20Address)
        public
        onlyOwner
    {
        require(
            nextUpERC20Address != address(0),
            "Admin: Next-Up contract address is null"
        );
        _nextUpContract = NextUp(nextUpERC20Address);
    }

    function setAthleteERC721Contract(address athleteERC721Address) public onlyOwner{
        require(
            athleteERC721Address != address(0),
            "Admin: Athlete ERC721 contract address is null"
        );
        _athleteERC721Contract = AthleteERC721(athleteERC721Address);
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

    function getUserBoughtNfts(address user) public view returns(uint[] memory){
        return _userBoughtAthNfts[user].values();
    }

    function getAthleteNfts(uint athleteId) public view isValidAthlete(athleteId) returns(uint[] memory){
        return _athleteNfts[athleteId].values();
    }

    function getSellerCreatedAthleteTokenpkg(address seller) public view returns(uint[] memory){
        return _sellersCreatedAthleteTokenpkg[seller].values();
    }

    function getValidAthleteTokenpkgIds()public view returns(uint[] memory){
        return _validAthleteTokenpkgIds.values();
    }

    //   --------------------------- Internal Functions ---------------------------

     function isEligibleForPkgCreation(address seller, uint athleteId, uint qtyToSell) internal returns(bool){
        _athleteERC20Contract = AthleteERC20(
            _athleteERC20Detail[athleteId].contractAddress
        );

        if (_athleteERC20Contract.balanceOf(seller) >= getLockedAthleteTokens(seller, athleteId) + qtyToSell){
            return true;
        }
        else{
            return false;
        }
    }

    function getLockedAthleteTokens(address seller, uint athleteId) internal view returns(uint){
        uint lockedTokens;

        uint256[] memory packageIds = _sellersCreatedAthleteTokenpkg[seller].values();

        for (uint i=0;i<packageIds.length;i++){
            if (_athleteTokenPkg[packageIds[i]].athleteId == athleteId){
                lockedTokens += _athleteTokenPkg[packageIds[i]].quantity;
            }
        }
        return lockedTokens;
    }
    
    function isValidDrop(uint256 athleteId, Drop[] memory drops)
        internal
        view
        returns (bool)
    {
        uint256 currentTime = block.timestamp;
        uint256 totalDropSupply = getAthleteTotalSupplyInDrops(athleteId);

        for (uint256 i = 0; i < drops.length; i++) {
            if (
                (drops[i].timestamp < currentTime) ||
                drops[i].price <= 0 ||
                drops[i].supply <= 0
            ) {
                return false;
            } else {
                totalDropSupply += drops[i].supply;
            }
        }

        if (
            (totalDropSupply +
                _athleteERC20Detail[athleteId].suppliedAmount +
                _athleteERC20Detail[athleteId].availableForSale) >
            _athleteERC20Detail[athleteId].maxSupply
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
        if (athleteDetails.price <= 0 ||
                athleteDetails.contractAddress == address(0) ||
                athleteDetails.isDisabled == true ||
                athleteDetails.maxSupply <= 0 ||
                athleteDetails.suppliedAmount > 0 ||
                athleteDetails.availableForSale > 0 ||
                athleteDetails.countMaxSupplyAsAvailableTokens == true
        )
        {
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
