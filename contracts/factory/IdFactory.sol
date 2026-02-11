// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import { IdentityProxy } from "../proxy/IdentityProxy.sol";
import { IIdFactory } from "./IIdFactory.sol";
import { IERC734 } from "../interface/IERC734.sol";
import { IIdentity } from "../interface/IIdentity.sol";
import { Errors } from "../libraries/Errors.sol";
import { KeyPurposes } from "../libraries/KeyPurposes.sol";
import { KeyTypes } from "../libraries/KeyTypes.sol";

contract IdFactory is IIdFactory, Ownable {
    uint256 private constant _MAX_WALLETS_PER_IDENTITY = 101;

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
        string memory _salt
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
        address identity = _deployIdentity(oidSalt, _wallet);
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
        bytes32[] memory _managementKeys
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

        address identity = _deployIdentity(oidSalt, address(this));

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
        string memory _salt
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
        address identity = _deployIdentity(tokenIdSalt, _tokenOwner);
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
            _wallets[identity].length < _MAX_WALLETS_PER_IDENTITY,
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
     *  @dev See {IdFactory-registerWalletToIdentity}.
     */
    function registerWalletToIdentity(
        address wallet,
        bytes calldata signature,
        uint256 expiry
    ) external override {
        require(wallet != address(0), Errors.ZeroAddress());
        require(block.timestamp <= expiry, Errors.ExpiredSignature(signature));

        address identity = msg.sender;
        bytes32 structHash = keccak256(
            abi.encode(wallet, identity, expiry, address(this), block.chainid)
        );

        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(structHash);
        (address signer, ECDSA.RecoverError error, ) = ECDSA.tryRecover(
            digest,
            signature
        );
        require(
            error == ECDSA.RecoverError.NoError && signer == wallet,
            Errors.InvalidSignature()
        );

        // require the wallet is a MANAGEMENT key on the identity
        bytes32 key = keccak256(abi.encode(wallet));
        require(
            IIdentity(identity).keyHasPurpose(key, KeyPurposes.MANAGEMENT),
            Errors.KeyDoesNotHavePurpose(key, KeyPurposes.MANAGEMENT)
        );

        // Check if wallet is already linked
        require(
            _userIdentity[wallet] == address(0),
            Errors.WalletAlreadyLinkedToIdentity(wallet)
        );
        require(
            _tokenIdentity[wallet] == address(0),
            Errors.TokenAlreadyLinked(wallet)
        );

        // Check max wallets per identity
        require(
            _wallets[identity].length < _MAX_WALLETS_PER_IDENTITY,
            Errors.MaxWalletsPerIdentityExceeded()
        );

        _userIdentity[wallet] = identity;
        _wallets[identity].push(wallet);
        emit WalletLinked(wallet, identity);
    }

    /**
     *  @dev See {IdFactory-unregisterWalletFromIdentity}.
     */
    function unregisterWalletFromIdentity(address wallet) external override {
        require(wallet != address(0), Errors.ZeroAddress());
        require(
            _userIdentity[wallet] == msg.sender,
            Errors.WalletNotLinkedToIdentity(wallet)
        );

        address identity = _userIdentity[wallet];
        delete _userIdentity[wallet];
        uint256 length = _wallets[identity].length;
        for (uint256 i = 0; i < length; i++) {
            if (_wallets[identity][i] == wallet) {
                _wallets[identity][i] = _wallets[identity][length - 1];
                _wallets[identity].pop();
                break;
            }
        }
        emit WalletUnlinked(wallet, identity);
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
        address _wallet
    ) private returns (address) {
        bytes memory _code = type(IdentityProxy).creationCode;
        bytes memory _constructData = abi.encode(
            implementationAuthority,
            _wallet
        );
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }
}
