pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ERC721Mock is ERC721 {
    constructor () ERC721("DeathRoadNFT", "DRACE") {

    }
    uint256 currentId;
    function mint(
        address _recipient
    ) external {
        currentId = currentId + 1;
        uint256 tokenId = currentId;

        _mint(_recipient, tokenId);
    }
}