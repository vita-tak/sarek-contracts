// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {HashStamp} from "../src/HashStamp.sol";

contract HashStampTest is Test {
    HashStamp public hashStamp;
    address public alice;
    address public bob;

    bytes32 constant ROOT_HASH = keccak256("test-root-hash");
    bytes32 constant OTHER_HASH = keccak256("other-root-hash");

    function setUp() public {
        alice = address(0x1111);
        bob = address(0x2222);
        hashStamp = new HashStamp();
    }

    // ── Original tests ────────────────────────────────────────────────────────

    function test_AnyoneCanStamp() public {
        vm.prank(alice);
        hashStamp.stamp(ROOT_HASH);
        assertTrue(hashStamp.verify(ROOT_HASH));
    }

    function test_StampRecordsCorrectStamper() public {
        vm.prank(alice);
        hashStamp.stamp(ROOT_HASH);
        (, address stampedBy) = hashStamp.getStamp(ROOT_HASH);
        assertEq(stampedBy, alice);
    }

    function test_StampRecordsCorrectTimestamp() public {
        uint48 before = uint48(block.timestamp);
        vm.prank(alice);
        hashStamp.stamp(ROOT_HASH);
        (uint48 timestamp,) = hashStamp.getStamp(ROOT_HASH);
        assertEq(timestamp, before);
    }

    function test_RevertIfAlreadyStamped() public {
        vm.prank(alice);
        hashStamp.stamp(ROOT_HASH);
        vm.prank(bob);
        vm.expectRevert(HashStamp.AlreadyStamped.selector);
        hashStamp.stamp(ROOT_HASH);
    }

    function test_UnstampedHashReturnsFalse() public view {
        assertFalse(hashStamp.verify(OTHER_HASH));
    }

    function test_UnstampedHashReturnsZeroData() public view {
        (uint48 timestamp, address stampedBy) = hashStamp.getStamp(OTHER_HASH);
        assertEq(timestamp, 0);
        assertEq(stampedBy, address(0));
    }

    function test_DifferentHashesAreIndependent() public {
        vm.prank(alice);
        hashStamp.stamp(ROOT_HASH);
        assertFalse(hashStamp.verify(OTHER_HASH));
    }

    function test_BobCanStampDifferentHash() public {
        vm.prank(alice);
        hashStamp.stamp(ROOT_HASH);
        vm.prank(bob);
        hashStamp.stamp(OTHER_HASH);
        assertTrue(hashStamp.verify(ROOT_HASH));
        assertTrue(hashStamp.verify(OTHER_HASH));
    }

    // ── verifyLeaf tests ──────────────────────────────────────────────────────

    function _buildTestTree() internal pure returns (
        bytes32 root,
        bytes32 leaf1,
        bytes32[] memory proof1
    ) {
        // Double-hash leaves — OpenZeppelin standard
        leaf1 = keccak256(abi.encodePacked(keccak256(abi.encodePacked("leaf1"))));
        bytes32 leaf2 = keccak256(abi.encodePacked(keccak256(abi.encodePacked("leaf2"))));
        bytes32 leaf3 = keccak256(abi.encodePacked(keccak256(abi.encodePacked("leaf3"))));

        // Sort pairs — same as sortPairs: true in merkletreejs
        bytes32 node12 = leaf1 < leaf2
            ? keccak256(abi.encodePacked(leaf1, leaf2))
            : keccak256(abi.encodePacked(leaf2, leaf1));

        bytes32 node33 = keccak256(abi.encodePacked(leaf3, leaf3));

        root = node12 < node33
            ? keccak256(abi.encodePacked(node12, node33))
            : keccak256(abi.encodePacked(node33, node12));

        // Proof for leaf1: [leaf2, node33]
        proof1 = new bytes32[](2);
        proof1[0] = leaf2;
        proof1[1] = node33;
    }

    function test_VerifyLeaf_ValidProof() public {
        (bytes32 root, bytes32 leaf1, bytes32[] memory proof1) = _buildTestTree();
        vm.prank(alice);
        hashStamp.stamp(root);
        assertTrue(hashStamp.verifyLeaf(root, leaf1, proof1));
    }

    function test_VerifyLeaf_InvalidProof() public {
        (bytes32 root, bytes32 leaf1, bytes32[] memory proof1) = _buildTestTree();
        vm.prank(alice);
        hashStamp.stamp(root);
        // Corrupt the proof
        proof1[0] = keccak256("wrong");
        assertFalse(hashStamp.verifyLeaf(root, leaf1, proof1));
    }

    function test_VerifyLeaf_UnstampedRoot() public view {
        (, bytes32 leaf1, bytes32[] memory proof1) = _buildTestTree();
        bytes32 fakeRoot = keccak256("never-stamped");
        assertFalse(hashStamp.verifyLeaf(fakeRoot, leaf1, proof1));
    }

    function test_VerifyLeaf_WrongLeaf() public {
        (bytes32 root,, bytes32[] memory proof1) = _buildTestTree();
        vm.prank(alice);
        hashStamp.stamp(root);
        bytes32 wrongLeaf = keccak256("not-in-tree");
        assertFalse(hashStamp.verifyLeaf(root, wrongLeaf, proof1));
    }
}