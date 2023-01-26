// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "../interface/IImplementationAuthority.sol";
import "../proxy/IdentityProxy.sol";
import "./IIdFactory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IdFactory is IIdFactory, Ownable {

    mapping(address => bool) private _tokenFactories;

    // address of the _implementationAuthority contract making the link to the implementation contract
    address private _implementationAuthority;

    // as it is not possible to deploy 2 times the same contract address, this mapping allows us to check which
    // salt is taken and which is not
    mapping(string => bool) private _saltTaken;

    // ONCHAINID of the wallet owner
    mapping(address => address) private _userIdentity;

    // wallets currently linked to an ONCHAINID
    mapping(address => address[]) private _wallets;


    // setting
    constructor (address implementationAuthority) {
        _implementationAuthority = implementationAuthority;
    }

    /**
     *  @dev See {IdFactory-addTokenFactory}.
     */
    function addTokenFactory (address _factory) external override onlyOwner {
        require(_factory != address(0), "invalid argument - zero address");
        require(!isTokenFactory(_factory), "already a factory");
        _tokenFactories[_factory] = true;
        emit TokenFactoryAdded(_factory);
    }

    /**
     *  @dev See {IdFactory-removeTokenFactory}.
     */
    function removeTokenFactory (address _factory) external override onlyOwner {
        require(_factory != address(0), "invalid argument - zero address");
        require(isTokenFactory(_factory), "not a factory");
        _tokenFactories[_factory] = false;
        emit TokenFactoryRemoved(_factory);
    }

    /**
     *  @dev See {IdFactory-createIdentity}.
     */
    function createIdentity(
        address _wallet,
        string memory _salt)
    external override returns (address) {
        require(_wallet != address(0), "invalid argument - zero address");
        require(keccak256(abi.encode(_salt)) != keccak256(abi.encode("")), "invalid argument - empty string");
        string memory oidSalt = string.concat("OID",_salt);
        require (!_saltTaken[oidSalt], "salt already taken");
        require (_userIdentity[_wallet] == address(0), "wallet already linked to an identity");
        address identity = _deployIdentity(oidSalt, _implementationAuthority, _wallet);
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
        address _owner,
        string memory _salt)
    external override returns (address) {
        require(isTokenFactory(msg.sender) || msg.sender == owner(), "only Factory or owner can call");
        require(_token != address(0), "invalid argument - zero address");
        require(_owner != address(0), "invalid argument - zero address");
        require(keccak256(abi.encode(_salt)) != keccak256(abi.encode("")), "invalid argument - empty string");
        string memory tokenIdSalt = string.concat("Token",_salt);
        require (!_saltTaken[tokenIdSalt], "salt already taken");
        require (_userIdentity[_token] == address(0), "token already linked to an identity");
        address identity = _deployIdentity(tokenIdSalt, _implementationAuthority, _owner);
        _saltTaken[tokenIdSalt] = true;
        _userIdentity[_token] = identity;
        _wallets[identity].push(_token);
        emit TokenLinked(_token, identity);
        return identity;
    }

    /**
     *  @dev See {IdFactory-linkWallet}.
     */
    function linkWallet(address _newWallet) external override {
        require(_newWallet != address(0), "invalid argument - zero address");
        require(_userIdentity[msg.sender] != address(0), "wallet not linked to an identity contract");
        require(_userIdentity[_newWallet] == address(0), "new wallet already linked");
        address identity = _userIdentity[msg.sender];
        require(_wallets[identity].length <= 100, "not more than 100 _wallets linked");
        _userIdentity[_newWallet] = identity;
        _wallets[identity].push(_newWallet);
        emit WalletLinked(_newWallet, identity);
    }

    /**
     *  @dev See {IdFactory-unlinkWallet}.
     */
    function unlinkWallet(address _oldWallet) external override {
        require(_oldWallet != address(0), "invalid argument - zero address");
        require(_oldWallet != msg.sender, "cannot be called on sender address");
        require(_userIdentity[msg.sender] == _userIdentity[_oldWallet], "only a linked wallet can unlink");
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
    function getIdentity(address _wallet) external override view returns (address) {
        return _userIdentity[_wallet];
    }

    /**
     *  @dev See {IdFactory-isSaltTaken}.
     */
    function isSaltTaken(string calldata _salt) external override view returns (bool) {
        return _saltTaken[_salt];
    }

    /**
     *  @dev See {IdFactory-getWallets}.
     */
    function getWallets(address _identity) external override view returns (address[] memory) {
        return _wallets[_identity];
    }

    /**
     *  @dev See {IdFactory-isTokenFactory}.
     */
    function isTokenFactory (address _factory) public override view returns(bool) {
        return _tokenFactories[_factory];
    }

    // deploy function with create2 opcode call
    // returns the address of the contract created
    function _deploy(string memory salt, bytes memory bytecode) private returns (address) {
        bytes32 saltBytes = bytes32(keccak256(abi.encodePacked(salt)));
        address addr;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let encoded_data := add(0x20, bytecode) // load initialization code.
            let encoded_size := mload(bytecode)     // load init code's length.
            addr := create2(0, encoded_data, encoded_size, saltBytes)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr);
        return addr;
    }

    // function used to deploy an identity using CREATE2
    function _deployIdentity
    (
        string memory _salt,
        address implementationAuthority,
        address _wallet
    ) private returns (address){
        bytes memory _code = type(IdentityProxy).creationCode;
        bytes memory _constructData = abi.encode(implementationAuthority, _wallet);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return _deploy(_salt, bytecode);
    }
}