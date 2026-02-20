// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IdentityProxy } from "../proxy/IdentityProxy.sol";
import { IIdFactory } from "./IIdFactory.sol";
import { IERC734 } from "../interface/IERC734.sol";
import { Errors } from "../libraries/Errors.sol";
import { IdentityTypes } from "../libraries/IdentityTypes.sol";
import { KeyPurposes } from "../libraries/KeyPurposes.sol";
import { KeyTypes } from "../libraries/KeyTypes.sol";

contract IdFactory is IIdFactory, Ownable {
    // address of the _implementationAuthority contract making the link to the implementation contract
    address public immutable implementationAuthority;

    mapping(address => bool) private _tokenFactories;

    // as it is not possible to deploy 2 times the same contract address, this mapping allows us to check which
    // salt is taken and which is not
    mapping(string => bool) private _saltTaken;

    // ONCHAINID of the wallet owner
    mapping(address => address) private _userIdentity;

    // wallets currently linked to an ONCHAINID
    mapping(address => address[]) private _wallets;

    // ONCHAINID of the token
    mapping(address => address) private _tokenIdentity;

    // token linked to an ONCHAINID
    mapping(address => address) private _tokenAddress;

    // setting
    constructor(address implementationAuthorityAddress) Ownable(msg.sender) {
        require(
            implementationAuthorityAddress != address(0),
            Errors.ZeroAddress()
        );
        implementationAuthority = implementationAuthorityAddress;
    }

    /**
     *  @dev See {IdFactory-addTokenFactory}.
     */
    function addTokenFactory(address _factory) external override onlyOwner {
        require(_factory != address(0), Errors.ZeroAddress());
        require(!isTokenFactory(_factory), Errors.AlreadyAFactory(_factory));
        _tokenFactories[_factory] = true;
        emit TokenFactoryAdded(_factory);
    }

    /**
     *  @dev See {IdFactory-removeTokenFactory}.
     */
    function removeTokenFactory(address _factory) external override onlyOwner {
        require(_factory != address(0), Errors.ZeroAddress());
        require(isTokenFactory(_factory), Errors.NotAFactory(_factory));
        _tokenFactories[_factory] = false;
        emit TokenFactoryRemoved(_factory);
    }

    /**
     *  @dev See {IdFactory-createIdentity}.
     */
    function createIdentity(
        address _wallet,
        string memory _salt,
        uint256 _identityType,
        address[] memory _claimAdders
    ) external override onlyOwner returns (address) {
        require(_wallet != address(0), Errors.ZeroAddress());
        require(
            keccak256(abi.encode(_salt)) != keccak256(abi.encode("")),
            Errors.EmptyString()
        );
        string memory oidSalt = string.concat("OID", _salt);
        require(!_saltTaken[oidSalt], Errors.SaltTaken(oidSalt));
        require(
            _userIdentity[_wallet] == address(0),
            Errors.WalletAlreadyLinkedToIdentity(_wallet)
        );

        address identity;
        if (_claimAdders.length > 0) {
            identity = _deployIdentity(oidSalt, address(this), _identityType);
            _setupIdentityKeys(identity, _wallet, _claimAdders);
        } else {
            identity = _deployIdentity(oidSalt, _wallet, _identityType);
        }

        _saltTaken[oidSalt] = true;
        _userIdentity[_wallet] = identity;
        _wallets[identity].push(_wallet);
        emit WalletLinked(_wallet, identity);
        return identity;
    }

    /**
     *  @dev See {IdFactory-createIdentityWithManagementKeys}.
     */
    function createIdentityWithManagementKeys(
        address _wallet,
        string memory _salt,
        bytes32[] memory _managementKeys,
        uint256 _identityType,
        address[] memory _claimAdders
    ) external override onlyOwner returns (address) {
        require(_wallet != address(0), Errors.ZeroAddress());
        require(
            keccak256(abi.encode(_salt)) != keccak256(abi.encode("")),
            Errors.EmptyString()
        );
        string memory oidSalt = string.concat("OID", _salt);
        require(!_saltTaken[oidSalt], Errors.SaltTaken(oidSalt));
        require(
            _userIdentity[_wallet] == address(0),
            Errors.WalletAlreadyLinkedToIdentity(_wallet)
        );
        require(_managementKeys.length > 0, Errors.EmptyListOfKeys());

        address identity = _deployIdentity(
            oidSalt,
            address(this),
            _identityType
        );

        for (uint256 i = 0; i < _managementKeys.length; i++) {
            require(
                _managementKeys[i] != keccak256(abi.encode(_wallet)),
                Errors.WalletAlsoListedInManagementKeys(_wallet)
            );
            IERC734(identity).addKey(
                _managementKeys[i],
                KeyPurposes.MANAGEMENT,
                KeyTypes.ECDSA
            );
        }

        _addClaimAdderKeys(identity, _claimAdders);

        IERC734(identity).removeKey(
            keccak256(abi.encode(address(this))),
            KeyPurposes.MANAGEMENT
        );

        _saltTaken[oidSalt] = true;
        _userIdentity[_wallet] = identity;
        _wallets[identity].push(_wallet);
        emit WalletLinked(_wallet, identity);

        return identity;
    }

    /**
     *  @dev See {IdFactory-createTokenIdentity}.
     */
    function createTokenIdentity(
        address _token,
        address _tokenOwner,
        string memory _salt,
        address[] memory _claimAdders
    ) external override returns (address) {
        require(
            isTokenFactory(msg.sender) || msg.sender == owner(),
            OwnableUnauthorizedAccount(msg.sender)
        );
        require(_token != address(0), Errors.ZeroAddress());
        require(_tokenOwner != address(0), Errors.ZeroAddress());
        require(
            keccak256(abi.encode(_salt)) != keccak256(abi.encode("")),
            Errors.EmptyString()
        );
        string memory tokenIdSalt = string.concat("Token", _salt);
        require(!_saltTaken[tokenIdSalt], Errors.SaltTaken(tokenIdSalt));
        require(
            _tokenIdentity[_token] == address(0),
            Errors.TokenAlreadyLinked(_token)
        );

        address identity;
        if (_claimAdders.length > 0) {
            identity = _deployIdentity(tokenIdSalt, address(this), IdentityTypes.ASSET);
            _setupIdentityKeys(identity, _tokenOwner, _claimAdders);
        } else {
            identity = _deployIdentity(tokenIdSalt, _tokenOwner, IdentityTypes.ASSET);
        }

        _saltTaken[tokenIdSalt] = true;
        _tokenIdentity[_token] = identity;
        _tokenAddress[identity] = _token;
        emit TokenLinked(_token, identity);
        return identity;
    }

    /**
     *  @dev See {IdFactory-linkWallet}.
     */
    function linkWallet(address _newWallet) external override {
        require(_newWallet != address(0), Errors.ZeroAddress());
        require(
            _userIdentity[msg.sender] != address(0),
            Errors.WalletNotLinkedToIdentity(msg.sender)
        );
        require(
            _userIdentity[_newWallet] == address(0),
            Errors.WalletAlreadyLinkedToIdentity(_newWallet)
        );
        require(
            _tokenIdentity[_newWallet] == address(0),
            Errors.TokenAlreadyLinked(_newWallet)
        );
        address identity = _userIdentity[msg.sender];
        require(
            _wallets[identity].length < 101,
            Errors.MaxWalletsPerIdentityExceeded()
        );
        _userIdentity[_newWallet] = identity;
        _wallets[identity].push(_newWallet);
        emit WalletLinked(_newWallet, identity);
    }

    /**
     *  @dev See {IdFactory-unlinkWallet}.
     */
    function unlinkWallet(address _oldWallet) external override {
        require(_oldWallet != address(0), Errors.ZeroAddress());
        require(
            _oldWallet != msg.sender,
            Errors.CannotBeCalledOnSenderAddress()
        );
        require(
            _userIdentity[msg.sender] == _userIdentity[_oldWallet],
            Errors.OnlyLinkedWalletCanUnlink()
        );
        address _identity = _userIdentity[_oldWallet];
        delete _userIdentity[_oldWallet];
        uint256 length = _wallets[_identity].length;
        for (uint256 i = 0; i < length; i++) {
            if (_wallets[_identity][i] == _oldWallet) {
                _wallets[_identity][i] = _wallets[_identity][length - 1];
                _wallets[_identity].pop();
                break;
            }
        }
        emit WalletUnlinked(_oldWallet, _identity);
    }

    /**
     *  @dev See {IdFactory-getIdentity}.
     */
    function getIdentity(
        address _wallet
    ) external view override returns (address) {
        if (_tokenIdentity[_wallet] != address(0)) {
            return _tokenIdentity[_wallet];
        }

        return _userIdentity[_wallet];
    }

    /**
     *  @dev See {IdFactory-isSaltTaken}.
     */
    function isSaltTaken(
        string calldata _salt
    ) external view override returns (bool) {
        return _saltTaken[_salt];
    }

    /**
     *  @dev See {IdFactory-getWallets}.
     */
    function getWallets(
        address _identity
    ) external view override returns (address[] memory) {
        return _wallets[_identity];
    }

    /**
     *  @dev See {IdFactory-getToken}.
     */
    function getToken(
        address _identity
    ) external view override returns (address) {
        return _tokenAddress[_identity];
    }

    /**
     *  @dev See {IdFactory-isTokenFactory}.
     */
    function isTokenFactory(
        address _factory
    ) public view override returns (bool) {
        return _tokenFactories[_factory];
    }

    // bootstraps an identity: adds claim adder keys, transfers ownership, removes factory key
    function _setupIdentityKeys(
        address _identity,
        address _owner,
        address[] memory _claimAdders
    ) private {
        _addClaimAdderKeys(_identity, _claimAdders);
        IERC734(_identity).addKey(
            keccak256(abi.encode(_owner)),
            KeyPurposes.MANAGEMENT,
            KeyTypes.ECDSA
        );
        IERC734(_identity).removeKey(
            keccak256(abi.encode(address(this))),
            KeyPurposes.MANAGEMENT
        );
    }

    // adds CLAIM_ADDER keys for each trusted claim issuer
    function _addClaimAdderKeys(
        address _identity,
        address[] memory _claimAdders
    ) private {
        for (uint256 i = 0; i < _claimAdders.length; i++) {
            IERC734(_identity).addKey(
                keccak256(abi.encode(_claimAdders[i])),
                KeyPurposes.CLAIM_ADDER,
                KeyTypes.ECDSA
            );
        }
    }

    // deploy function with create2 opcode call
    // returns the address of the contract created
    function _deploy(
        string memory salt,
        bytes memory bytecode
    ) private returns (address) {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, bytecode) // load initialization code.
            let encoded_size := mload(bytecode) // load init code's length.
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr);
        return addr;
    }

    // function used to deploy an identity using CREATE2
    function _deployIdentity(
        string memory _salt,
        address _wallet,
        uint256 _identityType
    ) private returns (address) {
        bytes memory _code = type(IdentityProxy).creationCode;
        bytes memory _constructData = abi.encode(
            implementationAuthority,
            _wallet,
            _identityType
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }
}
