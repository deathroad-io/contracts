pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/INFTStorage.sol";

contract NFTStorage is Ownable, INFTStorage {
    struct StorageSet {
        bytes[][] values;
    }
    StorageSet featureNamesSet;
    StorageSet featureValuesSet;

    function addFeatures(
        bytes[] memory _featureNames,
        bytes[] memory _featureValues
    ) external override onlyOwner {
        require(
            _featureNames.length == _featureValues.length,
            "Invalid length input"
        );
        featureNamesSet.values.push(_featureNames);
        featureValuesSet.values.push(_featureNames);
    }

    function addFeaturesMany(
        bytes[][] memory _featureNamesSet,
        bytes[][] memory _featureValuesSet
    ) external override onlyOwner {
        require(
            _featureNamesSet.length == _featureValuesSet.length,
            "Invalid length input"
        );
        for (uint256 i = 0; i < _featureNamesSet.length; i++) {
            require(
                _featureNamesSet[i].length == _featureValuesSet[i].length,
                "Invalid feature length input"
            );
            featureNamesSet.values.push(_featureNamesSet[i]);
            featureValuesSet.values.push(_featureValuesSet[i]);
        }
    }

    function getAllFeatures()
        external
        view
        override
        returns (
            bytes[][] memory _featureNames,
            bytes[][] memory _featureValues
        )
    {
        return (featureNamesSet.values, featureValuesSet.values);
    }

    function getSetLength() external view override returns (uint256) {
        return featureNamesSet.values.length;
    }

    function getFeaturesByIndex(uint256 index)
        external
        view
        override
        returns (bytes[] memory _featureNames, bytes[] memory _featureValues)
    {
        return (featureNamesSet.values[index], featureValuesSet.values[index]);
    }
}
