pragma solidity ^0.8.0;

library FeatureUtil {
    function hashCompareWithLengthCheck(string memory a, string memory b)
        internal
        pure
        returns (bool)
    {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
        }
    }

    function checkDataType(string memory _actual, string memory _expected)
        internal
        pure
    {
        require(hashCompareWithLengthCheck(_actual, _expected), "invalid data type");
    }

    function checkDataTypes(
        string memory _actual,
        string[2] memory _expectedEither
    ) internal pure {
        require(
            hashCompareWithLengthCheck(_actual, _expectedEither[0]) || hashCompareWithLengthCheck(_actual, _expectedEither[1]),
            "invalid data type"
        );
    }

    function decodeDataType(bytes memory _encodedFeature)
        internal
        pure
        returns (string memory, bytes memory)
    {
        return abi.decode(_encodedFeature, (string, bytes));
    }

    function encodeValueUint256(string memory _featureName, uint256 _value)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _encodedValue = abi.encode(_value);
        return abi.encode(_featureName, _encodedValue);
    }

    function decodeValueUint256(bytes memory _encodedFeature)
        internal
        pure
        returns (uint256 _value)
    {
        (string memory _dataType, bytes memory _encodedValue) = decodeDataType(
            _encodedFeature
        );
        checkDataTypes(_dataType, ["uint", "uint256"]);
        return abi.decode(_encodedValue, (uint256));
    }

    function encodeValueString(string memory _featureName, string memory _value)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _encodedValue = abi.encode(_value);
        return abi.encode(_featureName, _encodedValue);
    }

    function decodeValueString(bytes memory _encodedFeature)
        internal
        pure
        returns (string memory _value)
    {
        (string memory _dataType, bytes memory _encodedValue) = decodeDataType(
            _encodedFeature
        );
        checkDataType(_dataType, "string");
        return abi.decode(_encodedValue, (string));
    }


    function encodeValueBytes(string memory _featureName, bytes memory _value)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _encodedValue = abi.encode(_value);
        return abi.encode(_featureName, _encodedValue);
    }

    function decodeValueBytes(bytes memory _encodedFeature)
        internal
        pure
        returns (bytes memory _value)
    {
        (string memory _dataType, bytes memory _encodedValue) = decodeDataType(
            _encodedFeature
        );
        checkDataType(_dataType, "bytes");
        return abi.decode(_encodedValue, (bytes));
    }

    function encodeValueArrayUint256(string memory _featureName, uint256[] memory _value)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _encodedValue = abi.encode(_value);
        return abi.encode(_featureName, _encodedValue);
    }

    function decodeValueArrayUint256(bytes memory _encodedFeature)
        internal
        pure
        returns (uint256[] memory _value)
    {
        (string memory _dataType, bytes memory _encodedValue) = decodeDataType(
            _encodedFeature
        );
        checkDataTypes(_dataType, ["uint[]", "uint256[]"]);
        return abi.decode(_encodedValue, (uint256[]));
    }

    function encodeValueArrayString(string memory _featureName, string[] memory _value)
        internal
        pure
        returns (bytes memory)
    {
        bytes memory _encodedValue = abi.encode(_value);
        return abi.encode(_featureName, _encodedValue);
    }

    function decodeValueArrayString(bytes memory _encodedFeature)
        internal
        pure
        returns (string[] memory _value)
    {
        (string memory _dataType, bytes memory _encodedValue) = decodeDataType(
            _encodedFeature
        );
        checkDataType(_dataType, "string[]");
        return abi.decode(_encodedValue, (string[]));
    }
}
