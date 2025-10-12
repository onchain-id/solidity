// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { IAccount } from "@account-abstraction/contracts/interfaces/IAccount.sol";
import { IEntryPoint } from "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import { PackedUserOperation } from "@account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import { SIG_VALIDATION_SUCCESS } from "@account-abstraction/contracts/core/Helpers.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Exec } from "@account-abstraction/contracts/utils/Exec.sol";

/**
 * @title IdentitySmartAccount
 * @author OnChainID Team
 * @notice Abstract contract providing ERC-4337 Account Abstraction functionality for Identity contracts
 * @dev Abstract contract providing ERC-4337 Account Abstraction functionality for Identity contracts
 *
 * This contract handles:
 * - UserOperation validation and execution
 * - Entry point management
 * - Nonce management for UserOperations
 * - Missing funds handling
 * - Replay attack prevention
 *
 * @custom:security This contract uses ERC-7201 storage slots to prevent storage collision attacks
 * in upgradeable contracts.
 */
abstract contract IdentitySmartAccount is
    IAccount,
    Initializable,
    UUPSUpgradeable
{
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    /**
     * @dev Storage struct for ERC-4337 Account Abstraction data
     * @custom:storage-location erc7201:onchainid.identity.smartaccount.storage
     */
    struct SmartAccountStorage {
        /// @dev Entry point contract address for UserOperations
        IEntryPoint entryPoint;
    }

    /**
     * @dev Hardcoded Entry Point addresses per network
     * Official ERC-4337 Entry Point v0.6: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
     */
    IEntryPoint internal constant _DEFAULT_ENTRY_POINT =
        IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    /**
     * @dev ERC-7201 Storage Slot for ERC-4337 Account Abstraction data
     * This slot ensures no storage collision between different versions of the contract
     *
     * Formula: keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff))
     * where id is the namespace identifier
     */
    bytes32 internal constant _ENTRYPOINT_STORAGE_SLOT =
        keccak256(
            abi.encode(
                uint256(
                    keccak256(bytes("onchainid.identity.smartaccount.storage"))
                ) - 1
            )
        ) & ~bytes32(uint256(0xff));

    // ========= Events =========

    event EntryPointSet(address indexed entryPoint);

    // ========= Errors =========

    error ExecuteError(uint256 index, bytes error);

    // ========= Modifiers =========

    /**
     * @notice Requires the caller to be the entry point
     */
    modifier onlyEntryPoint() {
        require(
            msg.sender == address(entryPoint()),
            "IdentitySmartAccount: not from EntryPoint"
        );
        _;
    }

    /**
     * @dev Execute a batch of calls from the account (ERC-4337 standard)
     * @param calls Array of calls to execute
     */
    function executeBatch(Call[] calldata calls) external virtual {
        _requireForExecute();

        uint256 callsLength = calls.length;
        for (uint256 i = 0; i < callsLength; ++i) {
            Call calldata call = calls[i];
            bool ok = Exec.call(call.target, call.value, call.data, gasleft());
            if (!ok) {
                if (callsLength == 1) {
                    Exec.revertWithReturnData();
                } else {
                    revert ExecuteError(i, Exec.getReturnData(0));
                }
            }
        }
    }

    // ========= Public Functions =========

    /**
     * @dev See {IAccount-validateUserOp}.
     * @notice Validates a UserOperation for ERC-4337 Account Abstraction
     *
     * This function validates:
     * 1. The caller is the entry point
     * 2. The UserOperation signature is valid
     * 3. The signer has appropriate permissions (must be implemented by inheriting contract)
     * 4. The nonce is correct
     * 5. Handles missing account funds
     *
     * @param userOp The UserOperation to validate
     * @param userOpHash The hash of the UserOperation
     * @param missingAccountFunds Missing funds that need to be deposited
     * @return validationData Packed validation data (0 for success, 1 for signature failure)
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        virtual
        override(IAccount)
        onlyEntryPoint
        returns (uint256 validationData)
    {
        // 1. Validate signature and permissions in one step
        validationData = _validateSignature(userOp, userOpHash);
        if (validationData != SIG_VALIDATION_SUCCESS) {
            return validationData;
        }

        // 2. Validate nonce
        _validateNonce(userOp.nonce);

        // 3. Handle missing funds
        _payPrefund(missingAccountFunds);

        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Sets the entry point contract address
     * @param _entryPoint The new entry point contract address
     */
    function setEntryPoint(IEntryPoint _entryPoint) external virtual {
        _requireManager();
        _setEntryPoint(_entryPoint);
    }

    /**
     * @dev Deposit more funds for this account in the entryPoint
     */
    function addDeposit() public payable virtual {
        _requireManager();
        entryPoint().depositTo{ value: msg.value }(address(this));
    }

    /**
     * @dev Withdraw value from the account's deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawDepositTo(
        address payable withdrawAddress,
        uint256 amount
    ) public virtual {
        _requireManager();
        entryPoint().withdrawTo(withdrawAddress, amount);
    }

    /**
     * @dev Check current account deposit in the entryPoint
     * @return The current deposit amount
     */
    function getDeposit() public view virtual returns (uint256) {
        return entryPoint().balanceOf(address(this));
    }

    /**
     * @dev Returns the entry point contract address
     * @return The entry point contract address
     */
    function entryPoint() public view virtual returns (IEntryPoint) {
        return _getSmartAccountStorage().entryPoint;
    }

    /**
     * @dev Returns the current UserOperation nonce from the entry point
     * @return The current UserOperation nonce
     */
    function getNonce() public view virtual returns (uint256) {
        return entryPoint().getNonce(address(this), 0);
    }

    /**
     * @dev Validates the signature of a UserOperation and the signer's permissions
     * Must be implemented by inheriting contract
     * This function should:
     * 1. Recover the signer address from the signature
     * 2. Validate that the signature is valid (not address(0))
     * 3. Validate that the signer has required permissions
     * @param userOp The UserOperation to validate
     * @param userOpHash The hash of the UserOperation
     * @return validationData Packed validation data (0 for success, 1 for signature/permission failure)
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal virtual returns (uint256 validationData);

    /**
     * @dev Handles missing account funds by depositing to entry point
     * @param missingAccountFunds The amount of missing funds
     */
    function _payPrefund(uint256 missingAccountFunds) internal virtual {
        if (missingAccountFunds > 0) {
            entryPoint().depositTo{ value: missingAccountFunds }(address(this));
        }
    }

    /**
     * @dev Sets the entry point contract address
     * @param _entryPoint The new entry point contract address
     */
    function _setEntryPoint(IEntryPoint _entryPoint) internal virtual {
        require(
            address(_entryPoint) != address(0),
            "IdentitySmartAccount: zero address"
        );
        _getSmartAccountStorage().entryPoint = _entryPoint;
        emit EntryPointSet(address(_entryPoint));
    }

    // ========= Initialization =========

    /**
     * @dev Initializes the ERC-4337 functionality with default entry point
     */
    // solhint-disable-next-line func-name-mixedcase
    function __IdentitySmartAccount_init() internal onlyInitializing {
        __UUPSUpgradeable_init();
        _getSmartAccountStorage().entryPoint = _DEFAULT_ENTRY_POINT;
        emit EntryPointSet(address(_DEFAULT_ENTRY_POINT));
    }

    /**
     * @dev Reinitializes the ERC-4337 functionality for upgrades
     * @param versionNumber The version number for the reinitializer modifier
     */
    // solhint-disable-next-line func-name-mixedcase
    function __IdentitySmartAccount_init_unchained(
        uint8 versionNumber
    ) internal reinitializer(versionNumber) {
        _getSmartAccountStorage().entryPoint = _DEFAULT_ENTRY_POINT;
        emit EntryPointSet(address(_DEFAULT_ENTRY_POINT));
    }

    /**
     * @dev Internal function to authorize the upgrade of the contract.
     * This function is required by UUPSUpgradeable.
     * @param newImplementation The address of the new implementation.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}

    /**
     * @dev Requires the caller to have management permissions
     * Must be implemented by inheriting contract
     */
    function _requireManager() internal view virtual;

    /**
     * @dev Requires the caller to be authorized for execution
     * Must be implemented by inheriting contract for custom execution requirements
     */
    function _requireForExecute() internal view virtual;

    /**
     * @dev Validates the nonce of the UserOperation
     * Can be overridden by inheriting contract for custom nonce validation
     * @param nonce The nonce to validate
     */
    function _validateNonce(uint256 nonce) internal view virtual {
        require(nonce == getNonce(), "Invalid nonce");
    }

    /**
     * @dev Returns the SmartAccount storage struct at the specified ERC-7201 slot
     * @return s The SmartAccountStorage struct pointer for the smart account management slot
     */
    function _getSmartAccountStorage()
        internal
        pure
        returns (SmartAccountStorage storage s)
    {
        bytes32 slot = _ENTRYPOINT_STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
}
