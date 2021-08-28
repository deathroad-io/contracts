pragma solidity ^0.8.0;
import "./interfaces/INotaryNFT.sol";
contract NotaryNFT is INotaryNFT {
    function getUpgradeResult(bytes32 secret, address nftFactory) external override view returns (bool) {
        //TODO: implement notary
        return true;
    }
}