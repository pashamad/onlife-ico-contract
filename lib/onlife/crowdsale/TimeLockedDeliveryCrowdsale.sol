pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Ownable.sol";
import "../../openzepplin/crowdsale/distribution/FinalizableCrowdsale.sol";

import "../control/TimeLock.sol";

contract TimeLockedDeliveryCrowdsale is FinalizableCrowdsale, Ownable {
  using SafeMath for uint256;

  mapping(address => uint256) private _balances;

  TimeLock private _deliveryLock;

  constructor(uint256 unlockTime) public {
    _deliveryLock = new TimeLock(unlockTime);
  }

  function withdrawTokens(address beneficiary, bool testAfermath) public {
    require((testAfermath || !_deliveryLock.isLocked()), 'token delivery is locked');
    uint256 amount = _balances[beneficiary];
    require(amount > 0, 'requires positive amount');
    _balances[beneficiary] = 0;
    _deliverTokens(beneficiary, amount);
  }

  function releaseTokens(address beneficiary) internal onlyOwner {
    _balances[beneficiary] = 0;
  }

  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
    _balances[beneficiary] = _balances[beneficiary].add(tokenAmount);
  }
}
