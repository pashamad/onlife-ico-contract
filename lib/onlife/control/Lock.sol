pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Secondary.sol";

contract Lock is Secondary {

  enum LockState { Locked, Unlocked }

  LockState private _state;

  constructor() public {
    _state = LockState.Unlocked;
  }

  function isLocked() public view returns (bool) {
    return _state == LockState.Locked;
  }

  function lock() public onlyPrimary {
    require(_state == LockState.Unlocked, 'already locked');
    _state = LockState.Locked;
  }

  function unlock() public onlyPrimary {
    require(_state == LockState.Locked, 'not locked');
    _state = LockState.Unlocked;
  }
}
