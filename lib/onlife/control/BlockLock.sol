pragma solidity ^0.5.0;

contract BlockLock {

  enum LockState { Locked, Unlocked }

  uint256 private _threshold;

  constructor(uint256 threshold) public {
    _threshold = threshold;
  }

  function isLocked() public view returns (bool) {
    return _threshold >= block.number;
  }
}
