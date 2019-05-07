pragma solidity ^0.5.0;

import "../lib/openzepplin/crowdsale/emission/AllowanceCrowdsale.sol";
import "../lib/onlife/crowdsale/SoftRefundableCrowdsale.sol";

contract OnlsSeedSale is SoftRefundableCrowdsale, AllowanceCrowdsale {

  constructor(
    address salesOwner,
    address tokenOwner,
    uint256 tokenPrice,
    uint256 usdRate,
    uint256 minGoal,
    uint256 openingTime,
    uint256 unlockTime,
    uint256 closingTime,
    address payable fundsWallet,
    IERC20 token
  ) Crowdsale(_calculateRate(tokenPrice, usdRate), fundsWallet, token)
    TimedCrowdsale(openingTime, closingTime)
    FinalizableCrowdsale()
    AllowanceCrowdsale(tokenOwner)
    TimeLockedDeliveryCrowdsale(unlockTime)
    SoftRefundableCrowdsale(minGoal, salesOwner)
    public
  {
    //
  }

  function getTokenPrice() public view returns(uint256) {
    return rate();
  }

  function getTokenPrice(uint256 amount) public view returns(uint256) {
    return amount.mul(rate());
  }

  function _calculateRate(uint256 tokenPrice, uint256 usdRate) internal pure returns (uint256) {
    return tokenPrice.mul(usdRate);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    require(weiAmount.mod(rate()) == 0, 'invalid wei value passed');
    uint256 amount = weiAmount.div(rate());
    return amount;
  }
}
