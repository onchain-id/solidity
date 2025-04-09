// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.27;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IClaimIssuer } from "../interface/IClaimIssuer.sol";
import { IIdentity } from "../interface/IIdentity.sol";
import { Errors } from "../libraries/Errors.sol";

contract Verifier is Ownable {
    /// @dev All topics of claims required to pass verification.
    uint256[] public requiredClaimTopics;

    /// @dev Array containing all TrustedIssuers identity contract address allowed to issue claims required.
    IClaimIssuer[] public trustedIssuers;

    /// @dev Mapping between a trusted issuer address and the topics of claims they are trusted for.
    mapping(address => uint256[]) public trustedIssuerClaimTopics;

    /// @dev Mapping between a claim topic and the trusted issuers trusted for it.
    mapping(uint256 => IClaimIssuer[]) public claimTopicsToTrustedIssuers;

    /**
     *  this event is emitted when a claim topic has been added to the requirement list
     *  the event is emitted by the 'addClaimTopic' function
     *  `claimTopic` is the required claim topic added
     */
    event ClaimTopicAdded(uint256 indexed claimTopic);

    /**
     *  this event is emitted when a claim topic has been removed from the requirement list
     *  the event is emitted by the 'removeClaimTopic' function
     *  `claimTopic` is the required claim removed
     */
    event ClaimTopicRemoved(uint256 indexed claimTopic);

    /**
     *  this event is emitted when an issuer is added to the trusted list.
     *  the event is emitted by the addTrustedIssuer function
     *  `trustedIssuer` is the address of the trusted issuer's ClaimIssuer contract
     *  `claimTopics` is the set of claims that the trusted issuer is allowed to emit
     */
    event TrustedIssuerAdded(IClaimIssuer indexed trustedIssuer, uint256[] claimTopics);

    /**
     *  this event is emitted when an issuer is removed from the trusted list.
     *  the event is emitted by the removeTrustedIssuer function
     *  `trustedIssuer` is the address of the trusted issuer's ClaimIssuer contract
     */
    event TrustedIssuerRemoved(IClaimIssuer indexed trustedIssuer);

    /**
     *  this event is emitted when the set of claim topics is changed for a given trusted issuer.
     *  the event is emitted by the updateIssuerClaimTopics function
     *  `trustedIssuer` is the address of the trusted issuer's ClaimIssuer contract
     *  `claimTopics` is the set of claims that the trusted issuer is allowed to emit
     */
    event ClaimTopicsUpdated(IClaimIssuer indexed trustedIssuer, uint256[] claimTopics);

    modifier onlyVerifiedSender() {
        require(verify(_msgSender()), "sender is not verified");
        _;
    }

    /**
     *  @dev See {IClaimTopicsRegistry-removeClaimTopic}.
     */
    function addClaimTopic(uint256 claimTopic) public onlyOwner {
        uint256 length = requiredClaimTopics.length;
        require(length < 15, Errors.MaxClaimTopicsExceeded());
        for (uint256 i = 0; i < length; i++) {
            require(requiredClaimTopics[i] != claimTopic, Errors.ClaimTopicAlreadyExists(claimTopic));
        }
        requiredClaimTopics.push(claimTopic);
        emit ClaimTopicAdded(claimTopic);
    }

    /**
     *  @dev See {IClaimTopicsRegistry-getClaimTopics}.
     */
    function removeClaimTopic(uint256 claimTopic) public onlyOwner {
        uint256 length = requiredClaimTopics.length;
        for (uint256 i = 0; i < length; i++) {
            if (requiredClaimTopics[i] == claimTopic) {
                requiredClaimTopics[i] = requiredClaimTopics[length - 1];
                requiredClaimTopics.pop();
                emit ClaimTopicRemoved(claimTopic);
                break;
            }
        }
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-addTrustedIssuer}.
     */
    function addTrustedIssuer(IClaimIssuer trustedIssuer, uint256[] calldata claimTopics) public onlyOwner {
        require(address(trustedIssuer) != address(0), Errors.ZeroAddress());
        require(trustedIssuerClaimTopics[address(trustedIssuer)].length == 0, Errors.TrustedIssuerAlreadyExists(address(trustedIssuer)));
        require(claimTopics.length > 0, Errors.TrustedClaimTopicsCannotBeEmpty());
        require(claimTopics.length <= 15, Errors.MaxClaimTopicsExceeded());
        require(trustedIssuers.length < 50, Errors.MaxTrustedIssuersExceeded());
        trustedIssuers.push(trustedIssuer);
        trustedIssuerClaimTopics[address(trustedIssuer)] = claimTopics;
        for (uint256 i = 0; i < claimTopics.length; i++) {
            claimTopicsToTrustedIssuers[claimTopics[i]].push(trustedIssuer);
        }
        emit TrustedIssuerAdded(trustedIssuer, claimTopics);
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-removeTrustedIssuer}.
     */
    function removeTrustedIssuer(IClaimIssuer trustedIssuer) public onlyOwner {
        require(address(trustedIssuer) != address(0), Errors.ZeroAddress());
        require(trustedIssuerClaimTopics[address(trustedIssuer)].length != 0, Errors.NotATrustedIssuer(address(trustedIssuer)));
        uint256 length = trustedIssuers.length;
        for (uint256 i = 0; i < length; i++) {
            if (trustedIssuers[i] == trustedIssuer) {
                trustedIssuers[i] = trustedIssuers[length - 1];
                trustedIssuers.pop();
                break;
            }
        }
        for (
            uint256 claimTopicIndex = 0;
            claimTopicIndex < trustedIssuerClaimTopics[address(trustedIssuer)].length;
            claimTopicIndex++) {
            uint256 claimTopic = trustedIssuerClaimTopics[address(trustedIssuer)][claimTopicIndex];
            uint256 topicsLength = claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 i = 0; i < topicsLength; i++) {
                if (claimTopicsToTrustedIssuers[claimTopic][i] == trustedIssuer) {
                    claimTopicsToTrustedIssuers[claimTopic][i] =
                                        claimTopicsToTrustedIssuers[claimTopic][topicsLength - 1];
                    claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
            }
        }
        delete trustedIssuerClaimTopics[address(trustedIssuer)];
        emit TrustedIssuerRemoved(trustedIssuer);
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-updateIssuerClaimTopics}.
     */
    function updateIssuerClaimTopics(IClaimIssuer trustedIssuer, uint256[] calldata newClaimTopics) public onlyOwner {
        require(address(trustedIssuer) != address(0), Errors.ZeroAddress());
        require(trustedIssuerClaimTopics[address(trustedIssuer)].length != 0, Errors.NotATrustedIssuer(address(trustedIssuer)));
        require(newClaimTopics.length <= 15, Errors.MaxClaimTopicsExceeded());
        require(newClaimTopics.length > 0, Errors.TrustedClaimTopicsCannotBeEmpty());

        for (uint256 i = 0; i < trustedIssuerClaimTopics[address(trustedIssuer)].length; i++) {
            uint256 claimTopic = trustedIssuerClaimTopics[address(trustedIssuer)][i];
            uint256 topicsLength = claimTopicsToTrustedIssuers[claimTopic].length;
            for (uint256 j = 0; j < topicsLength; j++) {
                if (claimTopicsToTrustedIssuers[claimTopic][j] == trustedIssuer) {
                    claimTopicsToTrustedIssuers[claimTopic][j] =
                                        claimTopicsToTrustedIssuers[claimTopic][topicsLength - 1];
                    claimTopicsToTrustedIssuers[claimTopic].pop();
                    break;
                }
            }
        }
        trustedIssuerClaimTopics[address(trustedIssuer)] = newClaimTopics;
        for (uint256 i = 0; i < newClaimTopics.length; i++) {
            claimTopicsToTrustedIssuers[newClaimTopics[i]].push(trustedIssuer);
        }
        emit ClaimTopicsUpdated(trustedIssuer, newClaimTopics);
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-getTrustedIssuers}.
     */
    function getTrustedIssuers() public view returns (IClaimIssuer[] memory) {
        return trustedIssuers;
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-getTrustedIssuersForClaimTopic}.
     */
    function getTrustedIssuersForClaimTopic(uint256 claimTopic) public view returns (IClaimIssuer[] memory) {
        return claimTopicsToTrustedIssuers[claimTopic];
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-isTrustedIssuer}.
     */
    function isTrustedIssuer(address issuer) public view returns (bool) {
        if(trustedIssuerClaimTopics[issuer].length > 0) {
            return true;
        }
        return false;
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-getTrustedIssuerClaimTopics}.
     */
    function getTrustedIssuerClaimTopics(IClaimIssuer trustedIssuer) public view returns (uint256[] memory) {
        require(trustedIssuerClaimTopics[address(trustedIssuer)].length != 0, Errors.NotATrustedIssuer(address(trustedIssuer)));
        return trustedIssuerClaimTopics[address(trustedIssuer)];
    }

    /**
     *  @dev See {ITrustedIssuersRegistry-hasClaimTopic}.
     */
    function hasClaimTopic(address issuer, uint256 claimTopic) public view returns (bool) {
        uint256[] memory claimTopics = trustedIssuerClaimTopics[issuer];
        uint256 length = claimTopics.length;
        for (uint256 i = 0; i < length; i++) {
            if (claimTopics[i] == claimTopic) {
                return true;
            }
        }
        return false;
    }

    function isClaimTopicRequired(uint256 claimTopic) public view returns (bool) {
        uint256 length = requiredClaimTopics.length;

        for (uint256 i = 0; i < length; i++) {
            if (requiredClaimTopics[i] == claimTopic) {
                return true;
            }
        }

        return false;
    }

    /**
     * @dev Verify an identity (ONCHAINID) by checking if the identity has at least one valid claim from a trusted
     * issuer for each required claim topic. Returns true if the identity is compliant, false otherwise.
     */
    function verify(address identity) public view returns(bool isVerified) {
        if (requiredClaimTopics.length == 0) {
            return true;
        }

        uint256 foundClaimTopic;
        uint256 scheme;
        address issuer;
        bytes memory sig;
        bytes memory data;
        uint256 claimTopic;
        for (claimTopic = 0; claimTopic < requiredClaimTopics.length; claimTopic++) {
            IClaimIssuer[] memory trustedIssuersForClaimTopic =
                                this.getTrustedIssuersForClaimTopic(requiredClaimTopics[claimTopic]);

            if (trustedIssuersForClaimTopic.length == 0) {
                return false;
            }

            bytes32[] memory claimIds = new bytes32[](trustedIssuersForClaimTopic.length);
            for (uint256 i = 0; i < trustedIssuersForClaimTopic.length; i++) {
                claimIds[i] = keccak256(abi.encode(trustedIssuersForClaimTopic[i], requiredClaimTopics[claimTopic]));
            }

            for (uint256 j = 0; j < claimIds.length; j++) {
                (foundClaimTopic, scheme, issuer, sig, data, ) = IIdentity(identity).getClaim(claimIds[j]);

                if (foundClaimTopic == requiredClaimTopics[claimTopic]) {
                    try IClaimIssuer(issuer).isClaimValid(IIdentity(identity), requiredClaimTopics[claimTopic], sig,
                        data) returns(bool _validity) {

                        if (
                            _validity
                        ) {
                            j = claimIds.length;
                        }
                        if (!_validity && j == (claimIds.length - 1)) {
                            return false;
                        }
                    } catch {
                        if (j == (claimIds.length - 1)) {
                            return false;
                        }
                    }
                } else if (j == (claimIds.length - 1)) {
                    return false;
                }
            }
        }

        return true;
    }
}
