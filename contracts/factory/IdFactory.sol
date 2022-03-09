// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../interface/IImplementationAuthority.sol";
import "../proxy/IdentityProxy.sol";
import "./IIdFactory.sol";

contract IdFactory is IIdFactory {

    // event emitted whenever a single contract is deployed by the factory
    event Deployed(address _addr);

    event WalletLinked(address wallet, address identity);
    event WalletUnlinked(address wallet, address identity);

    // address of the implementationAuthority contract making the link to the implementation contract
    address implementationAuthority;

    // as it is not possible to deploy 2 times the same contract address, this mapping allows us to check which
    // salt is taken and which is not
    mapping(string => bool) saltTaken;

    // ONCHAINID of the wallet owner
    mapping(address => address) userIdentity;

    // wallets currently linked to an ONCHAINID
    mapping(address => address[]) wallets;


    // setting
    constructor (address _implementationAuthority) {
        implementationAuthority = _implementationAuthority;
    }

    // deploy function with create2 opcode call
    // returns the address of the contract created
    function deploy(string memory salt, bytes memory bytecode) internal returns (address) {
        bytes memory implInitCode = bytecode;
        address addr;
        assembly {
            let encoded_data := add(0x20, implInitCode) // load initialization code.
            let encoded_size := mload(implInitCode)     // load init code's length.
            addr := create2(0, encoded_data, encoded_size, salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
        emit Deployed(addr);
        return addr;
    }

    // function used to deploy an identity using CREATE2
    function deployIdentity
    (
        string memory _salt,
        address _implementationAuthority,
        address _wallet
    ) internal returns (address){
        bytes memory _code = type(IdentityProxy).creationCode;
        bytes memory _constructData = abi.encode(_implementationAuthority, _wallet);
        bytes memory bytecode = abi.encodePacked(_code, _constructData);
        return deploy(_salt, bytecode);
    }



    // function used to create a new identity contract
    // the function is deploying a proxy contract linked to the implementation contract
    // previously deployed and is taking a string as salt to deploy the ID
    function createIdentity(address _wallet, string memory _salt) public override returns (address) {
        require (!saltTaken[_salt], "salt already taken");
        require (userIdentity[_wallet] == address(0), "wallet already linked to an identity");
        address identity = deployIdentity(_salt, implementationAuthority, _wallet);
        saltTaken[_salt] = true;
        userIdentity[_wallet] = identity;
        wallets[identity].push(_wallet);
        emit WalletLinked(_wallet, identity);
        return identity;
    }

    // function used to link a new wallet to an existing identity contract
    // function has to be called by the ONCHAINID owner, i.e. a wallet already linked to the contract
    function linkWallet(address _newWallet) public override {
        require(userIdentity[msg.sender] != address(0), "wallet not linked to an identity contract");
        require(userIdentity[_newWallet] == address(0), "new wallet already linked");
        address identity = userIdentity[msg.sender];
        require(wallets[identity].length <= 100, "not more than 100 wallets linked");
        userIdentity[_newWallet] = identity;
        wallets[identity].push(_newWallet);
        emit WalletLinked(_newWallet, identity);
    }

    // function used to unlink a wallet from an identity contract
    // function has to be called by the ONCHAINID owner, i.e. a wallet already linked to the contract
    // cannot be called on msg.sender address to ensure there is always minimum 1 wallet linked to an ONCHAINID
    function unlinkWallet(address _oldWallet) public override {
        require(_oldWallet != msg.sender, "cannot be called on sender address");
        require(userIdentity[msg.sender] == userIdentity[_oldWallet], "only a linked wallet can unlink");
        address _identity = userIdentity[_oldWallet];
        delete userIdentity[_oldWallet];
        uint256 length = wallets[_identity].length;
        for (uint256 i = 0; i < length; i++) {
            if (wallets[_identity][i] == _oldWallet) {
                wallets[_identity][i] = wallets[_identity][length - 1];
                wallets[_identity].pop();
                break;
            }
        }
        emit WalletUnlinked(_oldWallet, _identity);
    }

    // getter function that returns the ONCHAINID contract address linked to a wallet
    function getIdentity(address _wallet) public override view returns (address) {
        return userIdentity[_wallet];
    }

    // getter function that returns the list of wallets linked to an ONCHAINID
    function getWallets(address _identity) public override view returns (address[] memory) {
        return wallets[_identity];
    }
}
