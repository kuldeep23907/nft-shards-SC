// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTShardERC721 is ERC721 {
    uint256 tokenId;
    
    constructor(string memory _name, string memory _symbol) public ERC721(_name, _symbol) {
        tokenId = 0;
    }
    
    function mint(
        string memory tokenURI
    ) external {
        uint256  newId = tokenId + 1;
        tokenId++;
        _mint(msg.sender, newId);
        
        _setTokenURI(tokenId, tokenURI);
    }
    
}
