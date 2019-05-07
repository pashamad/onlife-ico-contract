pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Secondary.sol";

contract Lockable is Secondary {

  enum LockState { Locked, Unlocked }

  LockState private _state;

  constructor() public {
    _state = LockState.Locked;
  }

  function isLocked() public view returns (bool) {
    return _state == LockState.Unlocked;
  }

  function lock() public onlyPrimary {
    require(!isLocked(), 'contract is locked');
    _state = LockState.Locked;
  }

  function unlock() public onlyPrimary {
    require(isLocked(), 'contract is not locked');
    _state = LockState.Unlocked;
  }
}
