pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Secondary.sol";

contract Lockable is Secondary {

  enum State { Locked, Unlocked }

  State private _state;

  function isLocked() public view returns (bool) {
    return _state == State.Locked;
  }

  function lock() public onlyPrimary {
    require(!isLocked(), 'contract is locked');
    _state = State.Locked;
  }

  function unlock() public onlyPrimary {
    require(isLocked(), 'contract is not locked');
    _state = State.Unlocked;
  }
}
