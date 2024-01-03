// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Pco2Token is ERC20 {
    constructor(string memory _projectName, string memory _projectSymbol) ERC20(_projectName, _projectSymbol) {}

    function mint(address to, uint256 mintAmount) public returns (bool) {
        _mint(to, mintAmount);
        return true;
    }

    function burn(address account, uint256 value) public returns (bool) {
        _burn(account, value);
        return true;
    }
}
