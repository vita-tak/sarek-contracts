// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HashStamp} from "../src/HashStamp.sol";
import {MMRVerifier} from "../src/MMRVerifier.sol";

contract MMRVerifierTest is Test {
    HashStamp public hashStamp;
    MMRVerifier public verifier;
    address public alice;

    // Domain tags — must match MMRVerifier.sol and EvmMMRService.
    bytes1 private constant LEAF_TAG = 0x00;
    bytes1 private constant NODE_TAG = 0x01;

    function setUp() public {
        alice = address(0x1111);
        hashStamp = new HashStamp();
        verifier = new MMRVerifier(address(hashStamp));
    }

    // Domain-separated leaf node — keccak256(0x00 || data)
    function _leaf(bytes32 data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(LEAF_TAG, data));
    }

    // Domain-separated internal node — keccak256(0x01 || left || right)
    function _node(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(NODE_TAG, left, right));
    }

    // Builds a 2-leaf MMR — one mountain, one peak.
    // Returned leaves are the RAW submitted hashes; the contract applies the
    // leaf tag internally, so siblings carry the tagged leaf nodes.
    function _build2LeafMMR() internal pure returns (
        bytes32 mmrRoot,
        bytes32 leaf0,
        bytes32 leaf1,
        bytes32[] memory siblings0,
        bytes32[] memory peaks
    ) {
        leaf0 = bytes32(uint256(0x1111));
        leaf1 = bytes32(uint256(0x2222));

        // Peak = node(leaf(leaf0), leaf(leaf1))
        bytes32 peak = _node(_leaf(leaf0), _leaf(leaf1));

        peaks = new bytes32[](1);
        peaks[0] = peak;

        // mmrRoot = peak (single peak)
        mmrRoot = peak;

        // Proof for leaf0: sibling is the tagged leaf node for leaf1
        siblings0 = new bytes32[](1);
        siblings0[0] = _leaf(leaf1);
    }

    // Builds a 3-leaf MMR — two mountains.
    function _build3LeafMMR() internal pure returns (
        bytes32 mmrRoot,
        bytes32 leaf0,
        bytes32 leaf2,
        bytes32[] memory siblings0,
        bytes32[] memory siblings2,
        bytes32[] memory peaks
    ) {
        leaf0 = bytes32(uint256(0x1111));
        bytes32 leaf1 = bytes32(uint256(0x2222));
        leaf2 = bytes32(uint256(0x3333));

        bytes32 peak0 = _node(_leaf(leaf0), _leaf(leaf1));
        bytes32 peak1 = _leaf(leaf2); // single-leaf mountain — peak is the tagged leaf

        peaks = new bytes32[](2);
        peaks[0] = peak0;
        peaks[1] = peak1;

        // mmrRoot = node(peak0, peak1)
        mmrRoot = _node(peak0, peak1);

        // Proof for leaf0 (mountain 0, localIndex 0): sibling is tagged leaf1
        siblings0 = new bytes32[](1);
        siblings0[0] = _leaf(leaf1);

        // Proof for leaf2 (mountain 1, localIndex 0): no siblings
        siblings2 = new bytes32[](0);
    }

    // ── verifyLeaf tests ──────────────────────────────────────────────────────

    function test_VerifyLeaf_2Leaves_Leaf0() public {
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0, bytes32[] memory peaks)
            = _build2LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        assertTrue(verifier.verifyLeaf(mmrRoot, leaf0, siblings0, peaks, 2, 0));
    }

    function test_VerifyLeaf_2Leaves_Leaf1() public {
        (bytes32 mmrRoot, bytes32 leaf0, bytes32 leaf1,, bytes32[] memory peaks)
            = _build2LeafMMR();

        // Sibling for leaf1 is the tagged leaf node for leaf0.
        bytes32[] memory siblings1 = new bytes32[](1);
        siblings1[0] = _leaf(leaf0);

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        assertTrue(verifier.verifyLeaf(mmrRoot, leaf1, siblings1, peaks, 2, 1));
    }

    function test_VerifyLeaf_3Leaves_Leaf0() public {
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0,, bytes32[] memory peaks)
            = _build3LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        assertTrue(verifier.verifyLeaf(mmrRoot, leaf0, siblings0, peaks, 3, 0));
    }

    function test_VerifyLeaf_3Leaves_Leaf2_NoSiblings() public {
        (bytes32 mmrRoot,, bytes32 leaf2,, bytes32[] memory siblings2, bytes32[] memory peaks)
            = _build3LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        assertTrue(verifier.verifyLeaf(mmrRoot, leaf2, siblings2, peaks, 3, 2));
    }

    function test_RevertIfRootNotStamped() public {
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0, bytes32[] memory peaks)
            = _build2LeafMMR();

        vm.expectRevert(MMRVerifier.RootNotStamped.selector);
        verifier.verifyLeaf(mmrRoot, leaf0, siblings0, peaks, 2, 0);
    }

    function test_ReturnFalseForTamperedLeaf() public {
        (bytes32 mmrRoot,,, bytes32[] memory siblings0, bytes32[] memory peaks)
            = _build2LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        bytes32 tamperedLeaf = bytes32(uint256(0x9999));
        assertFalse(verifier.verifyLeaf(mmrRoot, tamperedLeaf, siblings0, peaks, 2, 0));
    }

    function test_ReturnFalseForTamperedSibling() public {
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0, bytes32[] memory peaks)
            = _build2LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        siblings0[0] = bytes32(uint256(0x9999));
        assertFalse(verifier.verifyLeaf(mmrRoot, leaf0, siblings0, peaks, 2, 0));
    }

    function test_ReturnFalseForTamperedPeak() public {
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0, bytes32[] memory peaks)
            = _build2LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        peaks[0] = bytes32(uint256(0x9999));
        assertFalse(verifier.verifyLeaf(mmrRoot, leaf0, siblings0, peaks, 2, 0));
    }

    function test_RevertIfEmptyPeaks() public {
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0,)
            = _build2LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        bytes32[] memory emptyPeaks = new bytes32[](0);
        vm.expectRevert(MMRVerifier.EmptyPeaks.selector);
        verifier.verifyLeaf(mmrRoot, leaf0, siblings0, emptyPeaks, 2, 0);
    }

    // ── Domain-separation forgery rejection ───────────────────────────────────

    // A true internal node must not pass as a leaf. Under the old un-tagged
    // scheme the climb node(a, b) == peak would verify; the leaf tag breaks it.
    function test_RejectInternalNodeAsLeaf() public {
        // Real 4-leaf MMR: one mountain, one peak.
        bytes32 l0 = bytes32(uint256(0x1111));
        bytes32 l1 = bytes32(uint256(0x2222));
        bytes32 l2 = bytes32(uint256(0x3333));
        bytes32 l3 = bytes32(uint256(0x4444));
        bytes32 a = _node(_leaf(l0), _leaf(l1));
        bytes32 b = _node(_leaf(l2), _leaf(l3));
        bytes32 peak = _node(a, b);

        vm.prank(alice);
        hashStamp.stamp(peak);

        // Present internal node `a` as a leaf of a pretend 2-leaf tree, with the
        // real upper sibling `b`. The contract hashes the supplied leaf as
        // keccak256(0x00 || a), so the climb no longer reproduces the peak.
        bytes32[] memory siblings = new bytes32[](1);
        siblings[0] = b;
        bytes32[] memory peaks = new bytes32[](1);
        peaks[0] = peak;

        assertFalse(verifier.verifyLeaf(peak, a, siblings, peaks, 2, 0));
    }

    // A stamped root must not pass as a single-element tree (leaf == root).
    function test_RejectRootAsSingleElementTree() public {
        (bytes32 mmrRoot,,,,) = _build2LeafMMR();

        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        // Old scheme: current = root == peaks[0] -> true. With the leaf tag,
        // current = keccak256(0x00 || root) != root -> false.
        bytes32[] memory singlePeak = new bytes32[](1);
        singlePeak[0] = mmrRoot;
        bytes32[] memory noSiblings = new bytes32[](0);

        assertFalse(verifier.verifyLeaf(mmrRoot, mmrRoot, noSiblings, singlePeak, 1, 0));
    }

    // ── Constructor zero-address guard ────────────────────────────────────────

    function test_RevertConstructorWithZeroAddress() public {
        vm.expectRevert(MMRVerifier.ZeroAddress.selector);
        new MMRVerifier(address(0));
    }

    // ── siblings.length validation ────────────────────────────────────────────

    function test_RevertIfWrongSiblingsLength() public {
        // 2-leaf MMR: mountain height = 1, expected 1 sibling. Supply 2.
        (bytes32 mmrRoot, bytes32 leaf0,, bytes32[] memory siblings0, bytes32[] memory peaks)
            = _build2LeafMMR();
        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        bytes32[] memory wrongSiblings = new bytes32[](2);
        wrongSiblings[0] = siblings0[0];
        wrongSiblings[1] = bytes32(uint256(0xdead));

        vm.expectRevert(
            abi.encodeWithSelector(MMRVerifier.InvalidSiblingsLength.selector, 1, 2)
        );
        verifier.verifyLeaf(mmrRoot, leaf0, wrongSiblings, peaks, 2, 0);
    }

    function test_RevertIfZeroSiblingsForMultiLeafMountain() public {
        // 2-leaf MMR: mountain height = 1, expected 1 sibling. Supply 0.
        (bytes32 mmrRoot, bytes32 leaf0,,, bytes32[] memory peaks)
            = _build2LeafMMR();
        vm.prank(alice);
        hashStamp.stamp(mmrRoot);

        bytes32[] memory noSiblings = new bytes32[](0);
        vm.expectRevert(
            abi.encodeWithSelector(MMRVerifier.InvalidSiblingsLength.selector, 1, 0)
        );
        verifier.verifyLeaf(mmrRoot, leaf0, noSiblings, peaks, 2, 0);
    }
}
