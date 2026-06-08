// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HashStamp} from "../src/HashStamp.sol";
import {MMRVerifier} from "../src/MMRVerifier.sol";

contract MMRVerifierTest is Test {
    HashStamp public hashStamp;
    MMRVerifier public verifier;
    address public alice;

    function setUp() public {
        alice = address(0x1111);
        hashStamp = new HashStamp();
        verifier = new MMRVerifier(address(hashStamp));
    }

    // Mirrors EvmMMRService.hash() — keccak256(left || right)
    function _combine(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(left, right));
    }

    // Builds a 2-leaf MMR — one mountain, one peak
    function _build2LeafMMR() internal pure returns (
        bytes32 mmrRoot,
        bytes32 leaf0,
        bytes32 leaf1,
        bytes32[] memory siblings0,
        bytes32[] memory peaks
    ) {
        leaf0 = bytes32(uint256(0x1111));
        leaf1 = bytes32(uint256(0x2222));

        // Peak = keccak256(leaf0 || leaf1)
        bytes32 peak = keccak256(abi.encodePacked(leaf0, leaf1));

        peaks = new bytes32[](1);
        peaks[0] = peak;

        // mmrRoot = peak (single peak)
        mmrRoot = peak;

        // Proof for leaf0: sibling is leaf1
        siblings0 = new bytes32[](1);
        siblings0[0] = leaf1;
    }

    // Builds a 3-leaf MMR — two mountains
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

        bytes32 peak0 = keccak256(abi.encodePacked(leaf0, leaf1));
        bytes32 peak1 = leaf2;

        peaks = new bytes32[](2);
        peaks[0] = peak0;
        peaks[1] = peak1;

        // mmrRoot = keccak256(peak0 || peak1)
        mmrRoot = keccak256(abi.encodePacked(peak0, peak1));

        // Proof for leaf0 (mountain 0, localIndex 0): sibling is leaf1
        siblings0 = new bytes32[](1);
        siblings0[0] = leaf1;

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
        (bytes32 mmrRoot,, bytes32 leaf1,, bytes32[] memory peaks)
            = _build2LeafMMR();

        bytes32[] memory siblings1 = new bytes32[](1);
        siblings1[0] = bytes32(uint256(0x1111));

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
}