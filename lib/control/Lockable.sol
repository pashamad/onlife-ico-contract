pragma solidity ^0.5.0;

import "../ownership/Secondary.sol";
import "./Lock.sol";

/**
 * @title Lockable
 * @dev Provides locked state to derived contracts.
 */
contract Lockable is Secondary {

  Lock private _lock;

  modifier onlyWhenUnlocked() {
    require(!isLocked(), 'contract method is locked');
    _;
  }

  constructor() public {
    _lock = new Lock();
  }

  function isLocked() public view returns (bool) {
    return _lock.isLocked();
  }

  function lock() internal onlyPrimary {
    _lock.lock();
  }

  function unlock() internal onlyPrimary {
    _lock.unlock();
  }
}
