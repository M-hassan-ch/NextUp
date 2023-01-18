// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract AthleteERC20 is ERC20, ERC20Burnable, Pausable, Ownable{

    address _adminContract;

    constructor(string memory tokenName, string memory symbol) ERC20(tokenName, symbol) {    

    }

    modifier onlyAllowed(address caller){
        require(caller == _adminContract || caller == owner(), "AthleteERC20: Caller is not authorized");
        _;
    }

    modifier isValidAdminContract(){
        require(_adminContract != address(0), "AthleteERC20: Admin contract address is null");
        _;
    }

    function setAdminContract(address adminContract) public onlyOwner{
        require(adminContract != address(0), "AthleteERC20: Admin contract's address argument is null");
        _adminContract = adminContract;
    }

    function pause() public isValidAdminContract onlyAllowed(msg.sender) {
        _pause();
    }

    function unpause() public isValidAdminContract onlyAllowed(msg.sender) {
        _unpause();
    }

    function mint(address to, uint256 amount) public isValidAdminContract onlyAllowed(msg.sender) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

}