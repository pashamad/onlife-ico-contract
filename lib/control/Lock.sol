pragma solidity ^0.5.0;

import "../ownership/Secondary.sol";

/**
 * @title Lock
 * @dev Basic lock contract
 */
contract Lock is Secondary {

  enum LockState { Locked, Unlocked }

  event LockStateChanged(LockState state);

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

    emit LockStateChanged(LockState.Locked);
  }

  function unlock() public onlyPrimary {
    require(_state == LockState.Locked, 'not locked');
    _state = LockState.Unlocked;

    emit LockStateChanged(LockState.Unlocked);
  }
}
