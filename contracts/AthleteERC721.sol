// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract AthleteERC721 is ERC721, ERC721URIStorage, Pausable, Ownable, ERC721Burnable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    address public _adminContract;

    constructor(string memory tokenName, string memory symbol) ERC721(tokenName, symbol) {}

    modifier onlyAllowed(address caller){
        require(caller == _adminContract || caller == owner(), "AthleteERC721: Caller is not authorized");
        _;
    }

    modifier isValidAdminContract(){
        require(_adminContract != address(0), "AthleteERC721: Admin contract address is null");
        _;
    }

    function setAdminContract(address adminContract) public onlyOwner{
        require(adminContract != address(0), "AthleteERC721: Admin contract's address argument is null");
        _adminContract = adminContract;
    }

    function pause() public isValidAdminContract onlyAllowed(msg.sender) {
        _pause();
    }

    function unpause() public isValidAdminContract onlyAllowed(msg.sender) {
        _unpause();
    }

    function safeMint(address to, string memory uri) public isValidAdminContract onlyAllowed(msg.sender) returns(uint){
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        return _tokenIdCounter.current();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}