pragma solidity ^0.5.0;

contract TimeLock {

  enum LockState { Locked, Unlocked }

  uint256 private _threshold;

  constructor(uint256 threshold) public {
    _threshold = threshold;
  }

  function isLocked() public view returns (bool) {
    // solhint-disable-next-line not-rely-on-time
    return _threshold >= block.timestamp;
  }
}
