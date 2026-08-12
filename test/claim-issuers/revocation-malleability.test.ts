import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployIdentityFixture } from '../fixtures';

const SECP256K1_N = ethers.BigNumber.from(
  '0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141',
);

function reencodeV(signature: string): string {
  const v = parseInt(signature.slice(-2), 16);
  return signature.slice(0, -2) + (v - 27).toString(16).padStart(2, '0');
}

function highSFlip(signature: string): string {
  const r = signature.slice(0, 66);
  const s = ethers.BigNumber.from('0x' + signature.slice(66, 130));
  const v = parseInt(signature.slice(-2), 16);
  const sFlipped = SECP256K1_N.sub(s);
  const vFlipped = v === 27 ? 28 : 27;
  return r + sFlipped.toHexString().slice(2).padStart(64, '0') + vFlipped.toString(16);
}

describe('ClaimIssuer - signature malleability regression', () => {
  // Revocation is keyed on exact signature bytes (ClaimIssuer.revokedClaims), so a
  // malleated-but-valid variant of a revoked signature used to resurrect the claim:
  // isClaimValid(malleated) passed and addClaim overwrote the stored signature.
  it('rejects a revoked claim re-encoded with v in {0, 1}', async () => {
    const { claimIssuer, claimIssuerWallet, aliceWallet, aliceIdentity, aliceClaim666 } =
      await loadFixture(deployIdentityFixture);

    await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature);
    expect(
      await claimIssuer.isClaimValid(aliceIdentity.address, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data),
    ).to.be.false;

    const malleated = reencodeV(aliceClaim666.signature);
    expect(malleated).to.not.equal(aliceClaim666.signature);
    expect(
      await claimIssuer.isClaimValid(aliceIdentity.address, aliceClaim666.topic, malleated, aliceClaim666.data),
    ).to.be.false;

    await expect(
      aliceIdentity
        .connect(aliceWallet)
        .addClaim(aliceClaim666.topic, aliceClaim666.scheme, aliceClaim666.issuer, malleated, aliceClaim666.data, aliceClaim666.uri),
    ).to.be.revertedWith('invalid claim');
  });

  it('rejects a revoked claim re-signed via the high-s flip (r, n - s, v ^ 1)', async () => {
    const { claimIssuer, claimIssuerWallet, aliceWallet, aliceIdentity, aliceClaim666 } =
      await loadFixture(deployIdentityFixture);

    await claimIssuer.connect(claimIssuerWallet).revokeClaimBySignature(aliceClaim666.signature);
    expect(
      await claimIssuer.isClaimValid(aliceIdentity.address, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data),
    ).to.be.false;

    const malleated = highSFlip(aliceClaim666.signature);
    expect(malleated).to.not.equal(aliceClaim666.signature);
    expect(
      await claimIssuer.isClaimValid(aliceIdentity.address, aliceClaim666.topic, malleated, aliceClaim666.data),
    ).to.be.false;

    await expect(
      aliceIdentity
        .connect(aliceWallet)
        .addClaim(aliceClaim666.topic, aliceClaim666.scheme, aliceClaim666.issuer, malleated, aliceClaim666.data, aliceClaim666.uri),
    ).to.be.revertedWith('invalid claim');
  });

  it('still accepts the canonical signature', async () => {
    const { claimIssuer, aliceIdentity, aliceClaim666 } = await loadFixture(deployIdentityFixture);

    expect(
      await claimIssuer.isClaimValid(aliceIdentity.address, aliceClaim666.topic, aliceClaim666.signature, aliceClaim666.data),
    ).to.be.true;
  });
});
