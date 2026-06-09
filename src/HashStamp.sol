// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract HashStamp {
    struct StampData {
        uint48 timestamp;
        address stampedBy;
    }

    mapping(bytes32 => StampData) private _stamps;

    event Stamped(bytes32 indexed rootHash, address indexed stampedBy, uint48 timestamp);

    error AlreadyStamped();
    error RootNotFound();

    function stamp(bytes32 rootHash) external {
        if (_stamps[rootHash].timestamp != 0) revert AlreadyStamped();
        uint48 ts = uint48(block.timestamp);
        _stamps[rootHash] = StampData({ timestamp: ts, stampedBy: msg.sender });
        emit Stamped(rootHash, msg.sender, ts);
    }

    function verify(bytes32 rootHash) external view returns (bool) {
        return _stamps[rootHash].timestamp != 0;
    }

    function getStamp(bytes32 rootHash) external view returns (uint48 timestamp, address stampedBy) {
        StampData memory s = _stamps[rootHash];
        return (s.timestamp, s.stampedBy);
    }

}