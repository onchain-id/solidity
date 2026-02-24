import { ethers } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export interface ClaimData {
  id: string;
  identity: string;
  issuer: string;
  topic: number | bigint;
  scheme: number;
  data: string;
  signature: string;
  uri: string;
}

/**
 * Creates a claim with proper ID and signature
 * @param identity - The identity contract address
 * @param issuer - The claim issuer contract address
 * @param topic - The claim topic (number or bigint)
 * @param scheme - The claim scheme
 * @param data - The claim data
 * @param uri - The claim URI
 * @param issuerWallet - The signer used to sign the claim
 * @returns Promise<ClaimData> - The complete claim object
 */
export async function createClaim(
  identity: string,
  issuer: string,
  topic: number | bigint,
  scheme: number,
  data: string,
  uri: string,
  issuerWallet: HardhatEthersSigner
): Promise<ClaimData> {
  const claim: ClaimData = {
    id: "",
    identity,
    issuer,
    topic,
    scheme,
    data,
    signature: "",
    uri,
  };

  // Generate claim ID
  claim.id = ethers.keccak256(
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "uint256"],
      [claim.issuer, claim.topic]
    )
  );

  // Generate claim signature
  claim.signature = await issuerWallet.signMessage(
    ethers.getBytes(
      ethers.keccak256(
        ethers.AbiCoder.defaultAbiCoder().encode(
          ["address", "uint256", "bytes"],
          [claim.identity, claim.topic, claim.data]
        )
      )
    )
  );

  return claim;
}
