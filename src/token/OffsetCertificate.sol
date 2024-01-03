// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract OffsetCertificate is ERC721 {
    uint256 totalSupply;

    mapping(uint256 => string) private _tokenURIs;

    constructor() ERC721("OffsetCertificate", "OffsetCertificate") {}

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
        totalSupply++;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://ipfs.io/ipfs/QmNxv6dAd6njWr7X7ZuSSH1ekd7xL6iDS6dZ7hr31QpnTg/";
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
