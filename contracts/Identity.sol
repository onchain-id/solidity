pragma solidity ^0.5.0;

import "./ERC734.sol";
import "./IERC735.sol";

/**
 * @dev Implementation of the `IERC734` "KeyHolder" and the `IERC735` "ClaimHolder" interfaces into a common Identity Contract.
 */
contract Identity is ERC734, IERC735 {

    mapping (bytes32 => Claim) private claims;
    mapping (uint256 => bytes32[]) private claimsByTopic;

    /**
       * @notice Implementation of the addClaim function from the ERC-735 standard
       *  Require that the msg.sender has claim signer key.
       *
       * @param _topic The type of claim
       * @param _scheme The scheme with which this claim SHOULD be verified or how it should be processed.
       * @param _issuer The issuers identity contract address, or the address used to sign the above signature.
       * @param _signature Signature which is the proof that the claim issuer issued a claim of topic for this identity.
       * it MUST be a signed message of the following structure: keccak256(address identityHolder_address, uint256 _ topic, bytes data)
       * or keccak256(abi.encode(identityHolder_address, topic, data))
       * @param _data The hash of the claim data, sitting in another location, a bit-mask, call data, or actual data based on the claim scheme.
       * @param _uri The location of the claim, this can be HTTP links, swarm hashes, IPFS hashes, and such.
       *
       * @return Returns claimRequestId: COULD be send to the approve function, to approve or reject this claim.
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
    returns (bytes32 claimRequestId)
    {
        bytes32 claimId = keccak256(abi.encode(_issuer, _topic));

        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 3), "Permissions: Sender does not have claim signer key");
        }

        if (claims[claimId].issuer != _issuer) {
            claimsByTopic[_topic].push(claimId);
            claims[claimId].topic = _topic;
            claims[claimId].scheme = _scheme;
            claims[claimId].issuer = _issuer;
            claims[claimId].signature = _signature;
            claims[claimId].data = _data;
            claims[claimId].uri = _uri;

            emit ClaimAdded(
                claimId,
                _topic,
                _scheme,
                _issuer,
                _signature,
                _data,
                _uri
            );
        } else {
            claims[claimId].topic = _topic;
            claims[claimId].scheme = _scheme;
            claims[claimId].issuer = _issuer;
            claims[claimId].signature = _signature;
            claims[claimId].data = _data;
            claims[claimId].uri = _uri;

            emit ClaimChanged(
                claimId,
                _topic,
                _scheme,
                _issuer,
                _signature,
                _data,
                _uri
            );
        }

        return claimId;
    }

    /**
       * @notice Implementation of the removeClaim function from the ERC-735 standard
       * Require that the msg.sender has management key.
       * Can only be removed by the claim issuer, or the claim holder itself.
       *
       * @param _claimId The identity of the claim i.e. keccak256(address issuer_address + uint256 topic)
       *
       * @return Returns TRUE when the claim was removed.
       * triggers ClaimRemoved event
       */

    function removeClaim(bytes32 _claimId) public returns (bool success) {
        if (msg.sender != address(this)) {
            require(keyHasPurpose(keccak256(abi.encode(msg.sender)), 1), "Permissions: Sender does not have CLAIM key");
        }

        if (claims[_claimId].topic == 0) {
            revert("NonExisting: There is no claim with this ID");
        }

        uint claimIndex = 0;
        while (claimsByTopic[claims[_claimId].topic][claimIndex] != _claimId) {
            claimIndex++;
        }

        claimsByTopic[claims[_claimId].topic][claimIndex] = claimsByTopic[claims[_claimId].topic][claimsByTopic[claims[_claimId].topic].length - 1];
        claimsByTopic[claims[_claimId].topic].pop();

        emit ClaimRemoved(
            _claimId,
            claims[_claimId].topic,
            claims[_claimId].scheme,
            claims[_claimId].issuer,
            claims[_claimId].signature,
            claims[_claimId].data,
            claims[_claimId].uri
        );

        delete claims[_claimId];

        return true;
    }

    /**
        * @notice Implementation of the getClaim function from the ERC-735 standard.
        *
        * @param _claimId The identity of the claim i.e. keccak256(address issuer_address + uint256 topic)
        *
        * @return Returns all the parameters of the claim for the specified _claimId (topic, scheme, signature, issuer, data, uri) .
        */

    function getClaim(bytes32 _claimId)
    public
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
            claims[_claimId].topic,
            claims[_claimId].scheme,
            claims[_claimId].issuer,
            claims[_claimId].signature,
            claims[_claimId].data,
            claims[_claimId].uri
        );
    }

    /**
        * @notice Implementation of the getClaimIdsByTopic function from the ERC-735 standard.
        * used to get all the claims from the specified topic
        *
        * @param _topic The identity of the claim i.e. keccak256(address issuer_address + uint256 topic)
        *
        * @return Returns an array of claim IDs by topic.
        */

    function getClaimIdsByTopic(uint256 _topic)
    public
    view
    returns(bytes32[] memory claimIds)
    {
        return claimsByTopic[_topic];
    }
}
