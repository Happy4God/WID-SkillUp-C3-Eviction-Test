// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/* StudyToken - ERC20 token for Web3 Uni rewards system */
contract StudyToken is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("Study Token", "STUDY") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    /** Mint new tokens */
    function mint(address to, uint256 amount) external  {
        _mint(to, amount);
    }

    /**n Burn tokens from caller's balance*/
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}