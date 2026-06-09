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

}