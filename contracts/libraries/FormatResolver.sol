// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

library FormatResolver {
    /// @notice The formats we currently support
    enum FormatType {
        Unknown, // 0
        StringType, // 1
        TripleUint, // 2  => struct {uint256;uint256;uint256}
        Uint16Type, // 3
        StringArray, // 4
        AddressType // 5
    }

    /// @notice Turn format integer into a `FormatType`
    function resolve(uint256 formatId) internal pure returns (FormatType) {
        if (formatId == 1) return FormatType.StringType;
        if (formatId == 2) return FormatType.TripleUint;
        if (formatId == 3) return FormatType.Uint16Type;
        if (formatId == 4) return FormatType.StringArray;
        if (formatId == 5) return FormatType.AddressType;
        return FormatType.Unknown;
    }

    /// @notice Decode a `string` from raw bytes
    function decodeString(
        bytes memory data
    ) internal pure returns (string memory) {
        return abi.decode(data, (string));
    }

    /// @notice Decode `{uint256;uint256;uint256}` struct from raw bytes
    function decodeTripleUint(
        bytes memory data
    ) internal pure returns (uint256 a, uint256 b, uint256 c) {
        return abi.decode(data, (uint256, uint256, uint256));
    }

    /// @notice Decode a `uint16` (packed as uint256 in ABI) from raw bytes
    function decodeUint16(bytes memory data) internal pure returns (uint16) {
        uint256 raw = abi.decode(data, (uint256));
        require(raw <= type(uint16).max, "FormatResolver: overflow");
        return uint16(raw);
    }

    /// @notice Decode a `string[]` from raw bytes
    function decodeStringArray(
        bytes memory data
    ) internal pure returns (string[] memory) {
        return abi.decode(data, (string[]));
    }

    /// @notice Decode an `address` from raw bytes
    function decodeAddress(bytes memory data) internal pure returns (address) {
        return abi.decode(data, (address));
    }
}
