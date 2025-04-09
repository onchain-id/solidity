// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;


interface IIdFactory {

    /// events

    // event emitted whenever a single contract is deployed by the factory
    event Deployed(address indexed _addr);

    // event emitted when a wallet is linked to an ONCHAINID contract
    event WalletLinked(address indexed wallet, address indexed identity);

    // event emitted when a token is linked to an ONCHAINID contract
    event TokenLinked(address indexed token, address indexed identity);

    // event emitted when a wallet is unlinked from an ONCHAINID contract
    event WalletUnlinked(address indexed wallet, address indexed identity);

    // event emitted when an address is registered on the factory as a Token
    // factory address, granting this address the privilege to issue
    // Onchain identities for tokens
    event TokenFactoryAdded(address indexed factory);

    // event emitted when a previously recorded token factory address is removed
    event TokenFactoryRemoved(address indexed factory);

    /// functions

    /**
     *  @dev function used to create a new Identity proxy from the factory
     *  @param _wallet the wallet address of the primary owner of this ONCHAINID contract
     *  @param _salt the salt used by create2 to issue the contract
     *  requires a new salt for each deployment
     *  _wallet cannot be linked to another ONCHAINID
     *  only Owner can call => Owner is supposed to be a smart contract, managing the accessibility
     *  of the function, including calls to oracles for multichain
     *  deployment security (avoid identity theft), defining payment requirements, etc.
     */
    function createIdentity(address _wallet, string memory _salt) external returns (address);

    /**
     *  @dev function used to create a new Identity proxy from the factory, setting the wallet and listed keys as
     * MANAGEMENT keys.
     *  @param _wallet the wallet address of the primary owner of this ONCHAINID contract
     *  @param _salt the salt used by create2 to issue the contract
     *  @param _managementKeys A list of keys hash (keccak256(abiEncoded())) to add as MANAGEMENT keys.
     *  requires a new salt for each deployment
     *  _wallet cannot be linked to another ONCHAINID
     *  only Owner can call => Owner is supposed to be a smart contract, managing the accessibility
     *  of the function, including calls to oracles for multichain
     *  deployment security (avoid identity theft), defining payment requirements, etc.
     */
    function createIdentityWithManagementKeys(
        address _wallet,
        string memory _salt,
        bytes32[] memory _managementKeys
    ) external returns (address);

    /**
     *  @dev function used to create a new Token Identity proxy from the factory
     *  @param _token the address of the token contract
     *  @param _tokenOwner the owner address of the token
     *  @param _salt the salt used by create2 to issue the contract
     *  requires a new salt for each deployment
     *  _token cannot be linked to another ONCHAINID
     *  only Token factory or owner can call (owner should only use its privilege
     *  for tokens not issued by a Token factory onchain
     */
    function createTokenIdentity(address _token, address _tokenOwner, string memory _salt) external returns (address);

    /**
     *  @dev function used to link a new wallet to an existing identity
     *  @param _newWallet the address of the wallet to link
     *  requires msg.sender to be linked to an existing onchainid
     *  the _newWallet will be linked to the same OID contract as msg.sender
     *  _newWallet cannot be linked to an OID yet
     *  _newWallet cannot be address 0
     *  cannot link more than 100 wallets to an OID, for gas consumption reason
     */
    function linkWallet(address _newWallet) external;

    /**
     *  @dev function used to unlink a wallet from an existing identity
     *  @param _oldWallet the address of the wallet to unlink
     *  requires msg.sender to be linked to the same onchainid as _oldWallet
     *  msg.sender cannot be _oldWallet to keep at least 1 wallet linked to any OID
     *  _oldWallet cannot be address 0
     */
    function unlinkWallet(address _oldWallet) external;

    /**
     *  @dev function used to register an address as a token factory
     *  @param _factory the address of the token factory
     *  can be called only by Owner
     *  _factory cannot be registered yet
     *  once the factory has been registered it can deploy token identities
     */
    function addTokenFactory(address _factory) external;

    /**
     *  @dev function used to unregister an address previously registered as a token factory
     *  @param _factory the address of the token factory
     *  can be called only by Owner
     *  _factory has to be registered previously
     *  once the factory has been unregistered it cannot deploy token identities anymore
     */
    function removeTokenFactory(address _factory) external;

    /**
     *  @dev getter for OID contract corresponding to a wallet/token
     *  @param _wallet the wallet/token address
     */
    function getIdentity(address _wallet) external view returns (address);

    /**
     *  @dev getter to fetch the array of wallets linked to an OID contract
     *  @param _identity the address of the OID contract
     *  returns an array of addresses linked to the OID
     */
    function getWallets(address _identity) external view returns (address[] memory);

    /**
     *  @dev getter to fetch the token address linked to an OID contract
     *  @param _identity the address of the OID contract
     *  returns the address linked to the OID
     */
    function getToken(address _identity) external view returns (address);

    /**
     *  @dev getter to know if an address is registered as token factory or not
     *  @param _factory the address of the factory
     *  returns true if the address corresponds to a registered factory
     */
    function isTokenFactory(address _factory) external view returns(bool);

    /**
     *  @dev getter to know if a salt is taken for the create2 deployment
     *  @param _salt the salt used for deployment
     */
    function isSaltTaken(string calldata _salt) external view returns (bool);

    /**
     * @dev getter for the implementation authority used by this factory.
     */
    function implementationAuthority() external view returns (address);
}
