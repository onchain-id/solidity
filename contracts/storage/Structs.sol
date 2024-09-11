// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.27;

contract Structs {

   /**
    *  @dev Definition of the structure of a Key.
    *
    *  Specification: Keys are cryptographic public keys, or contract addresses associated with this identity.
    *  The structure should be as follows:
    *  key: A public key owned by this identity
    *  purposes: uint256[] Array of the key purposes, like 1 = MANAGEMENT, 2 = EXECUTION
    *  keyType: The type of key used, which would be a uint256 for different key types. e.g. 1 = ECDSA, 2 = RSA, etc.
    *  key: bytes32 The public key. // Its the Keccak256 hash of the key
    */
    struct Key {
        uint256[] purposes;
        uint256 keyType;
        bytes32 key;
    }

    /**
    *  @dev Definition of the structure of an Execution
    *
    *  Specification: Executions are requests for transactions to be issued by the ONCHAINID
    *  to: address of contract to interact with, can be address(this)
    *  value: ETH to transfer with the transaction
    *  data: payload of the transaction to execute
    *  approved: approval status of the Execution
    *  executed: execution status of the Execution (set as false when the Execution is created
    *  and updated to true when the Execution is processed)
    */
    struct Execution {
        address to;
        uint256 value;
        bytes data;
        bool approved;
        bool executed;
    }

   /**
    *  @dev Definition of the structure of a Claim.
    *
    *  Specification: Claims are information an issuer has about the identity holder.
    *  The structure should be as follows:
    *  claim: A claim published for the Identity.
    *  topic: A uint256 number which represents the topic of the claim. (e.g. 1 biometric, 2 residence (ToBeDefined:
    *  number schemes, sub topics based on number ranges??))
    *  scheme : The scheme with which this claim SHOULD be verified or how it should be processed. Its a uint256 for
    *  different schemes. E.g. could 3 mean contract verification, where the data will be call data, and the issuer a
    *  contract address to call (ToBeDefined). Those can also mean different key types e.g. 1 = ECDSA, 2 = RSA, etc.
    *  (ToBeDefined)
    *  issuer: The issuers identity contract address, or the address used to sign the above signature. If an
    *  identity contract, it should hold the key with which the above message was signed, if the key is not present
    *  anymore, the claim SHOULD be treated as invalid. The issuer can also be a contract address itself, at which the
    *  claim can be verified using the call data.
    *  signature: Signature which is the proof that the claim issuer issued a claim of topic for this identity. it
    *  MUST be a signed message of the following structure: `keccak256(abi.encode(identityHolder_address, topic, data))`
    *  data: The hash of the claim data, sitting in another location, a bit-mask, call data, or actual data based on
    *  the claim scheme.
    *  uri: The location of the claim, this can be HTTP links, swarm hashes, IPFS hashes, and such.
    */
    struct Claim {
        uint256 topic;
        uint256 scheme;
        address issuer;
        bytes signature;
        bytes data;
        string uri;
    }
}
