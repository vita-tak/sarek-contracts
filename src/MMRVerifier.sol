// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import "./HashStamp.sol";

/**
 * MMRVerifier — on-chain Merkle Mountain Range leaf verification.
 *
 * Verifies that a leaf belongs to an MMR whose root has been stamped
 * in HashStamp. Pure mathematics — no state, no storage writes.
 *
 * Hash function: keccak256 with leaf/node domain separation — matches
 * EvmMMRService in ledger-service:
 *   leaf = keccak256(0x00 || data), node = keccak256(0x01 || left || right).
 * The tags stop a true internal node (or the root itself) from being
 * re-presented as a leaf under an honestly stamped root.
 */
contract MMRVerifier {
    HashStamp public immutable hashStamp;

    // Domain tags binding a hash to its position in the tree.
    bytes1 private constant LEAF_TAG = 0x00;
    bytes1 private constant NODE_TAG = 0x01;

    error RootNotStamped();
    error EmptyPeaks();
    error LeafIndexOutOfRange();

    constructor(address hashStampAddress) {
        hashStamp = HashStamp(hashStampAddress);
    }

    /**
     * Verifies a leaf inclusion proof against a stamped MMR root.
     *
     * @param mmrRoot    MMR root — must exist in HashStamp
     * @param leaf       Hash of the original data
     * @param siblings   Sibling hashes along the path to the peak
     * @param peaks      All MMR peaks at time of stamping
     * @param leafCount  Total leaves in MMR at time of stamping
     * @param leafIndex  Zero-based index of the leaf in the MMR
     */
    function verifyLeaf(
        bytes32 mmrRoot,
        bytes32 leaf,
        bytes32[] calldata siblings,
        bytes32[] calldata peaks,
        uint32 leafCount,
        uint32 leafIndex
    ) external view returns (bool) {
        if (!hashStamp.verify(mmrRoot)) revert RootNotStamped();
        if (peaks.length == 0) revert EmptyPeaks();

        // Find which mountain the leaf belongs to
        (uint256 mountainIndex, uint256 localIndex) = _locateLeaf(
            leafIndex,
            leafCount
        );

        // Climb the mountain using siblings. The supplied leaf is domain-tagged
        // before the climb so it can never collide with an internal node.
        bytes32 current = keccak256(abi.encodePacked(LEAF_TAG, leaf));
        uint256 idx = localIndex;

        for (uint256 i = 0; i < siblings.length; i++) {
            if (idx % 2 == 0) {
                current = keccak256(abi.encodePacked(NODE_TAG, current, siblings[i]));
            } else {
                current = keccak256(abi.encodePacked(NODE_TAG, siblings[i], current));
            }
            idx /= 2;
        }

        // Computed peak must match the correct mountain peak
        if (mountainIndex >= peaks.length) return false;
        if (current != peaks[mountainIndex]) return false;

        // Bag peaks and verify root
        return _bagPeaks(peaks) == mmrRoot;
    }

    /**
     * Finds which mountain a leaf belongs to.
     * Mirrors MMRService.locateLeaf() in ledger-service.
     */
   function _locateLeaf(
    uint32 leafIndex,
    uint32 leafCount
    ) internal pure returns (uint256 mountainIndex, uint256 localIndex) {
        uint256 offset = 0;
        mountainIndex = 0;

        for (uint256 i = 32; i > 0; i--) {
            uint256 size = uint256(1) << (i - 1);
            if (uint256(leafCount) & size != 0) {
                if (uint256(leafIndex) < offset + size) {
                    return (mountainIndex, uint256(leafIndex) - offset);
                }
                offset += size;
                mountainIndex++;
            }
        }
        revert LeafIndexOutOfRange();
    }

    /**
     * Bags all peaks into a single root hash.
     * Mirrors MMRService.getRoot() in ledger-service.
     */
    function _bagPeaks(
    bytes32[] calldata peaks
    ) internal pure returns (bytes32) {
        if (peaks.length == 1) return peaks[0];

        bytes32 result = peaks[peaks.length - 1];
        for (uint256 i = peaks.length - 1; i > 0; i--) {
            result = keccak256(abi.encodePacked(NODE_TAG, peaks[i - 1], result));
        }
        return result;
    }
}