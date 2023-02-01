// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import "./interface/IIdentity.sol";
import "./interface/IClaimIssuer.sol";
import "./version/Version.sol";
import "./storage/Storage.sol";

/**
 * @dev Implementation of the `IERC734` "KeyHolder" and the `IERC735` "ClaimHolder" interfaces
 * into a common Identity Contract.
 * This implementation has a separate contract were it declares all storage,
 * allowing for it to be used as an upgradable logic contract.
 */
contract Identity is Storage, IIdentity, Version {

    /**
     * @notice Prevent any direct calls to the implementation contract (marked by _canInteract = false).
     */
    modifier delegatedOnly() {
        require(_canInteract == true, "Interacting with the library contract is forbidden.");
        _;
    }

    constructor(address initialManagementKey, bool _isLibrary) {
        _canInteract = !_isLibrary;

        if (_canInteract) {
            __Identity_init(initialManagementKey);
        } else {
            _initialized = true;
        }
    }

    /**
     * @notice When using this contract as an implementation for a proxy, call this initializer with a delegatecall.
     *
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     */
    function initialize(address initialManagementKey) public {
        __Identity_init(initialManagementKey);
    }

    /**
    * @notice implementation of the addKey function of the ERC-734 standard
    * Adds a _key to the identity. The _purpose specifies the purpose of key. Initially we propose four purposes:
    * 1: MANAGEMENT keys, which can manage the identity
    * 2: ACTION keys, which perform actions in this identities name (signing, logins, transactions, etc.)
    * 3: CLAIM signer keys, used to sign claims on other identities which need to be revokable.
    * 4: ENCRYPTION keys, used to encrypt data e.g. hold in claims.
    * MUST only be done by keys of purpose 1, or the identity itself.
    * If its the identity itself, the approval process will determine its approval.
    *
    * @param _key keccak256 representation of an ethereum address
    * @param _type type of key used, which would be a uint256 for different key types. e.g. 1 = ECDSA, 2 = RSA, etc.
    * @param _purpose a uint256[] Array of the key types, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
    *
    * @return success Returns TRUE if the addition was successful and FALSE if not
    */
    function addKey(bytes32 _key, uint256 _purpose, uint256 _type)
    public
    delegatedOnly
    override
    returns (bool success)
    {
        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 1), "Permissions: Sender does not have management key");
        }

        if (_keys[_key].key == _key) {
            for (uint keyPurposeIndex = 0; keyPurposeIndex < _keys[_key].purposes.length; keyPurposeIndex++) {
                uint256 purpose = _keys[_key].purposes[keyPurposeIndex];

                if (purpose == _purpose) {
                    revert("Conflict: Key already has purpose");
                }
            }

            _keys[_key].purposes.push(_purpose);
        } else {
            _keys[_key].key = _key;
            _keys[_key].purposes = [_purpose];
            _keys[_key].keyType = _type;
        }

        _keysByPurpose[_purpose].push(_key);

        emit KeyAdded(_key, _purpose, _type);

        return true;
    }

    /**
     *  @notice Approves an execution or claim addition.
     * If the sender is an ACTION key and the destination address is not the identity contract itself, then the
     * approval is authorized and the operation would be performed.
     * If the destination address is the identity itself, then the execution would be authorized and performed only
     * if the sender is a MANAGEMENT key.
     */
    function approve(uint256 _id, bool _approve)
    public
    delegatedOnly
    override
    returns (bool success)
    {
        require(_id < _executionNonce, "Cannot approve a non-existing execution");
        require(!_executions[_id].executed, "Request already executed");

        if(_executions[_id].to == address(this)) {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 1), "Sender does not have management key");
        }
        else {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 2), "Sender does not have action key");
        }

        emit Approved(_id, _approve);

        if (_approve == true) {
            _executions[_id].approved = true;
            _executions[_id].executed = true;

            // solhint-disable-next-line avoid-low-level-calls
            (success,) = _executions[_id].to.call{value:(_executions[_id].value)}(_executions[_id].data);

            if (success) {
                emit Executed(
                    _id,
                    _executions[_id].to,
                    _executions[_id].value,
                    _executions[_id].data
                );

                return true;
            } else {
                emit ExecutionFailed(
                    _id,
                    _executions[_id].to,
                    _executions[_id].value,
                    _executions[_id].data
                );

                revert("Execution failed.");
            }
        } else {
            _executions[_id].approved = false;
            return false;
        }
    }

    /**
     * @notice Passes an execution instruction to the keymanager.
     * If the sender is an ACTION key and the destination address is not the identity contract itself, then the
     * execution is immediately approved and performed.
     * If the destination address is the identity itself, then the execution would be performed immediately only if
     * the sender is a MANAGEMENT key.
     * Otherwise, the execute method triggers an ExecutionRequested event, and the execution request must be approved
     * using the `approve` method.
     *
     * @return executionId to use in the approve function, to approve or reject this execution.
     */
    function execute(address _to, uint256 _value, bytes memory _data)
    public
    delegatedOnly
    override
    payable
    returns (uint256 executionId)
    {
        uint256 _executionId = _executionNonce;
        require(!_executions[_executionId].executed, "Already executed");
        _executions[_executionId].to = _to;
        _executions[_executionId].value = _value;
        _executions[_executionId].data = _data;
        _executionNonce++;

        emit ExecutionRequested(_executionId, _to, _value, _data);

        if (keyHasPurpose(keccak256(abi.encode(msg.sender)), 1)) {
            approve(_executionId, true);
        }
        else if (_to != address(this) && keyHasPurpose(keccak256(abi.encode(msg.sender)), 2)){
            approve(_executionId, true);
        }

        return _executionId;
    }

    /**
    * @notice Remove the purpose from a key.
    */
    function removeKey(bytes32 _key, uint256 _purpose)
    public
    delegatedOnly
    override
    returns (bool success)
    {
        require(_keys[_key].key == _key, "NonExisting: Key isn't registered");

        if (msg.sender != address(this)) {
            require(
                keyHasPurpose(keccak256(abi.encode(msg.sender)), 1)
                , "Permissions: Sender does not have management key");
        }

        require(_keys[_key].purposes.length > 0, "NonExisting: Key doesn't have such purpose");

        uint purposeIndex = 0;
        while (_keys[_key].purposes[purposeIndex] != _purpose) {
            purposeIndex++;

            if (purposeIndex >= _keys[_key].purposes.length) {
                break;
            }
        }

        require(purposeIndex < _keys[_key].purposes.length, "NonExisting: Key doesn't have such purpose");

        _keys[_key].purposes[purposeIndex] = _keys[_key].purposes[_keys[_key].purposes.length - 1];
        _keys[_key].purposes.pop();

        uint keyIndex = 0;

        while (_keysByPurpose[_purpose][keyIndex] != _key) {
            keyIndex++;
        }

        _keysByPurpose[_purpose][keyIndex] = _keysByPurpose[_purpose][_keysByPurpose[_purpose].length - 1];
        _keysByPurpose[_purpose].pop();

        uint keyType = _keys[_key].keyType;

        if (_keys[_key].purposes.length == 0) {
            delete _keys[_key];
        }

        emit KeyRemoved(_key, _purpose, keyType);

        return true;
    }

    /**
    * @notice Implementation of the addClaim function from the ERC-735 standard
    *  Require that the msg.sender has claim signer key.
    *
    * @param _topic The type of claim
    * @param _scheme The scheme with which this claim SHOULD be verified or how it should be processed.
    * @param _issuer The issuers identity contract address, or the address used to sign the above signature.
    * @param _signature Signature which is the proof that the claim issuer issued a claim of topic for this identity.
    * it MUST be a signed message of the following structure:
    * keccak256(abi.encode(address identityHolder_address, uint256 _ topic, bytes data))
    * @param _data The hash of the claim data, sitting in another
    * location, a bit-mask, call data, or actual data based on the claim scheme.
    * @param _uri The location of the claim, this can be HTTP links, swarm hashes, IPFS hashes, and such.
    *
    * @return claimRequestId Returns claimRequestId: COULD be
    * send to the approve function, to approve or reject this claim.
    * triggers ClaimAdded event.
    */
    function addClaim(
        uint256 _topic,
        uint256 _scheme,
        address _issuer,
        bytes memory _signature,
        bytes memory _data,
        string memory _uri
    )
    public
    delegatedOnly
    override
    returns (bytes32 claimRequestId)
    {
        require(IClaimIssuer(_issuer).isClaimValid(IIdentity(address(this)), _topic, _signature, _data), "invalid claim");
        bytes32 claimId = keccak256(abi.encode(_issuer, _topic));
        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 3), "Permissions: Sender does not have claim signer key");
        }
        if (_claims[claimId].issuer != _issuer) {
            _claimsByTopic[_topic].push(claimId);
            _claims[claimId].topic = _topic;
            _claims[claimId].scheme = _scheme;
            _claims[claimId].issuer = _issuer;
            _claims[claimId].signature = _signature;
            _claims[claimId].data = _data;
            _claims[claimId].uri = _uri;
            emit ClaimAdded(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
        } else {
            _claims[claimId].topic = _topic;
            _claims[claimId].scheme = _scheme;
            _claims[claimId].issuer = _issuer;
            _claims[claimId].signature = _signature;
            _claims[claimId].data = _data;
            _claims[claimId].uri = _uri;

            emit ClaimChanged(claimId, _topic, _scheme, _issuer, _signature, _data, _uri);
        }
        return claimId;
    }

    /**
    * @notice Implementation of the removeClaim function from the ERC-735 standard
    * Require that the msg.sender has management key.
    * Can only be removed by the claim issuer, or the claim holder itself.
    *
    * @param _claimId The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
    *
    * @return success Returns TRUE when the claim was removed.
    * triggers ClaimRemoved event
    */
    function removeClaim(bytes32 _claimId) public delegatedOnly override returns (bool success) {
        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 3), "Permissions: Sender does not have CLAIM key");
        }

        if (_claims[_claimId].topic == 0) {
            revert("NonExisting: There is no claim with this ID");
        }

        uint claimIndex = 0;
        while (_claimsByTopic[_claims[_claimId].topic][claimIndex] != _claimId) {
            claimIndex++;
        }

        _claimsByTopic[_claims[_claimId].topic][claimIndex] =
        _claimsByTopic[_claims[_claimId].topic][_claimsByTopic[_claims[_claimId].topic].length - 1];
        _claimsByTopic[_claims[_claimId].topic].pop();

        emit ClaimRemoved(
            _claimId,
            _claims[_claimId].topic,
            _claims[_claimId].scheme,
            _claims[_claimId].issuer,
            _claims[_claimId].signature,
            _claims[_claimId].data,
            _claims[_claimId].uri
        );

        delete _claims[_claimId];

        return true;
    }

    /**
    * @notice Implementation of the getClaim function from the ERC-735 standard.
    *
    * @param _claimId The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
    *
    * @return topic Returns all the parameters of the claim for the
    * specified _claimId (topic, scheme, signature, issuer, data, uri) .
    * @return scheme Returns all the parameters of the claim for the
    * specified _claimId (topic, scheme, signature, issuer, data, uri) .
    * @return issuer Returns all the parameters of the claim for the
    * specified _claimId (topic, scheme, signature, issuer, data, uri) .
    * @return signature Returns all the parameters of the claim for the
    * specified _claimId (topic, scheme, signature, issuer, data, uri) .
    * @return data Returns all the parameters of the claim for the
    * specified _claimId (topic, scheme, signature, issuer, data, uri) .
    * @return uri Returns all the parameters of the claim for the
    * specified _claimId (topic, scheme, signature, issuer, data, uri) .
    */
    function getClaim(bytes32 _claimId)
    public
    override
    view
    returns(
        uint256 topic,
        uint256 scheme,
        address issuer,
        bytes memory signature,
        bytes memory data,
        string memory uri
    )
    {
        return (
        _claims[_claimId].topic,
        _claims[_claimId].scheme,
        _claims[_claimId].issuer,
        _claims[_claimId].signature,
        _claims[_claimId].data,
        _claims[_claimId].uri
        );
    }

    /**
    * @notice Implementation of the getClaimIdsByTopic function from the ERC-735 standard.
    * used to get all the claims from the specified topic
    *
    * @param _topic The identity of the claim i.e. keccak256(abi.encode(_issuer, _topic))
    *
    * @return claimIds Returns an array of claim IDs by topic.
    */
    function getClaimIdsByTopic(uint256 _topic)
    public
    override
    view
    returns(bytes32[] memory claimIds)
    {
        return _claimsByTopic[_topic];
    }

    /**
    * @notice Returns true if the key has MANAGEMENT purpose or the specified purpose.
    */
    function keyHasPurpose(bytes32 _key, uint256 _purpose)
    public
    override
    view
    returns(bool result)
    {
        Key memory key = _keys[_key];
        if (key.key == 0) return false;

        for (uint keyPurposeIndex = 0; keyPurposeIndex < key.purposes.length; keyPurposeIndex++) {
            uint256 purpose = key.purposes[keyPurposeIndex];

            if (purpose == 1 || purpose == _purpose) return true;
        }

        return false;
    }

    /**
     * @notice Implementation of the getKey function from the ERC-734 standard
     *
     * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
     *
     * @return purposes Returns the full key data, if present in the identity.
     * @return keyType Returns the full key data, if present in the identity.
     * @return key Returns the full key data, if present in the identity.
     */
    function getKey(bytes32 _key)
    public
    override
    view
    returns(uint256[] memory purposes, uint256 keyType, bytes32 key)
    {
        return (_keys[_key].purposes, _keys[_key].keyType, _keys[_key].key);
    }

    /**
    * @notice gets the purposes of a key
    *
    * @param _key The public key.  for non-hex and long keys, its the Keccak256 hash of the key
    *
    * @return _purposes Returns the purposes of the specified key
    */
    function getKeyPurposes(bytes32 _key)
    public
    override
    view
    returns(uint256[] memory _purposes)
    {
        return (_keys[_key].purposes);
    }

    /**
        * @notice gets all the keys with a specific purpose from an identity
        *
        * @param _purpose a uint256[] Array of the key types, like 1 = MANAGEMENT, 2 = ACTION, 3 = CLAIM, 4 = ENCRYPTION
        *
        * @return keys Returns an array of public key bytes32 hold by this identity and having the specified purpose
        */
    function getKeysByPurpose(uint256 _purpose)
    public
    override
    view
    returns(bytes32[] memory keys)
    {
        return _keysByPurpose[_purpose];
    }

    /**
     * @notice Initializer internal function for the Identity contract.
     *
     * @param initialManagementKey The ethereum address to be set as the management key of the ONCHAINID.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __Identity_init(address initialManagementKey) internal {
        require(!_initialized || _isConstructor(), "Initial key was already setup.");
        _initialized = true;
        _canInteract = true;

        bytes32 _key = keccak256(abi.encode(initialManagementKey));
        _keys[_key].key = _key;
        _keys[_key].purposes = [1];
        _keys[_key].keyType = 1;
        _keysByPurpose[1].push(_key);
        emit KeyAdded(_key, 1, 1);
    }

    /**
     * @notice Computes if the context in which the function is called is a constructor or not.
     *
     * @return true if the context is a constructor.
     */
    function _isConstructor() private view returns (bool) {
        address self = address(this);
        uint256 cs;
        // solhint-disable-next-line no-inline-assembly
        assembly { cs := extcodesize(self) }
        return cs == 0;
    }
}
