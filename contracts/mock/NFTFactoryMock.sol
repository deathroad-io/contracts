pragma solidity ^0.8.0;

import "../nft/NFTFactory.sol";

contract NFTFactoryMock is NFTFactory {
    function mint(
        address _recipient,
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) external {
        nft.mint(_recipient, _featureNames, _featureValues);
    }

    function mintCharm(
        address _recipient
    ) public {
        nft.buyCharm(_recipient);
    }
}
