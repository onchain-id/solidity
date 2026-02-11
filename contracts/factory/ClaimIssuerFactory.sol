// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { CREATE3 } from "solady/src/utils/CREATE3.sol";

import { Errors } from "../libraries/Errors.sol";

contract ClaimIssuerFactory is Ownable {
    address private _implementation;
    mapping(address => address) private _deployedClaimIssuers;
    mapping(address => bool) private _blacklistedAddresses;

    /// @notice Event emitted when a new ClaimIssuer is deployed
    event ClaimIssuerDeployed(
        address indexed managementKey,
        address indexed claimIssuer
    );

    /// @notice Event emitted when an address is blacklisted
    event Blacklisted(address indexed addr, bool blacklisted);

    /// @notice Event emitted when the implementation is updated
    event ImplementationUpdated(
        address indexed oldImplementation,
        address indexed newImplementation
    );

    constructor(address implementationAddress) Ownable(msg.sender) {
        _implementation = implementationAddress;
    }

    /**
     * @dev Deploys a new ClaimIssuer contract using CREATE2
     * @return The address of the deployed ClaimIssuer contract
     */
    function deployClaimIssuer() external returns (address) {
        return _deployClaimIssuer(msg.sender);
    }

    /**
     * @dev Deploys a ClaimIssuer on behalf of a management key (owner only)
     * @param managementKey The initial management key for the ClaimIssuer
     * @return The address of the deployed ClaimIssuer contract
     */
    function deployClaimIssuerOnBehalf(
        address managementKey
    ) external onlyOwner returns (address) {
        return _deployClaimIssuer(managementKey);
    }

    /**
     * @dev Blacklists an address from deploying ClaimIssuers
     * @param addr The address to blacklist
     */
    function blacklistAddress(
        address addr,
        bool blacklisted
    ) external onlyOwner {
        require(addr != address(0), Errors.ZeroAddress());
        _blacklistedAddresses[addr] = blacklisted;
        emit Blacklisted(addr, blacklisted);
    }

    /**
     * @dev Updates the implementation address
     * @param newImplementation The new implementation address
     */
    function updateImplementation(
        address newImplementation
    ) external onlyOwner {
        require(newImplementation != address(0), Errors.ZeroAddress());

        address oldImplementation = _implementation;
        _implementation = newImplementation;
        emit ImplementationUpdated(oldImplementation, newImplementation);
    }

    /**
     * @dev Getter for the current implementation contract used
     * @return The address of the implementation contract
     */
    function implementation() external view returns (address) {
        return _implementation;
    }

    /**
     * @dev returns the blacklist status of an address
     * @return true if blacklisted, false if not
     */
    function isBlacklisted(address account) external view returns (bool) {
        return _blacklistedAddresses[account];
    }

    /**
     * @dev Getter for the ClaimIssuer Proxy address linked to an account address
     * @return The address of the corresponding ClaimIssuer Proxy
     */
    function claimIssuer(address account) external view returns (address) {
        return _deployedClaimIssuers[account];
    }

    /**
     * @dev Deploys a new ClaimIssuer contract using CREATE2
     * @param managementKey The initial management key for the ClaimIssuer
     * @return The address of the deployed ClaimIssuer contract
     */
    function _deployClaimIssuer(
        address managementKey
    ) internal returns (address) {
        require(managementKey != address(0), Errors.ZeroAddress());
        require(
            !_blacklistedAddresses[msg.sender],
            Errors.Blacklisted(msg.sender)
        );
        require(
            _deployedClaimIssuers[managementKey] == address(0),
            Errors.ClaimIssuerAlreadyDeployed(managementKey)
        );

        address claimIssuerAddress = CREATE3.deployDeterministic(
            abi.encodePacked(
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    _implementation,
                    abi.encodeWithSelector(
                        bytes4(keccak256("initialize(address)")),
                        managementKey
                    )
                )
            ),
            bytes32(uint256(uint160(managementKey)))
        );

        _deployedClaimIssuers[managementKey] = claimIssuerAddress;
        emit ClaimIssuerDeployed(managementKey, claimIssuerAddress);

        return claimIssuerAddress;
    }
}
