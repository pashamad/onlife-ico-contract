pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Ownable.sol";
import "./FinalizableCrowdsale.sol";
import "../control/Lockable.sol";

contract LockedDeliveryCrowdsale is FinalizableCrowdsale, Ownable, Lockable {
  using SafeMath for uint256;

  mapping(address => uint256) private _balances;

  function withdrawTokens(address beneficiary) public onlyWhenUnlocked {
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
