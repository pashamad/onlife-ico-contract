pragma solidity ^0.5.0;

import "../lib/openzepplin/crowdsale/emission/AllowanceCrowdsale.sol";
import "../lib/onlife/crowdsale/SoftRefundableCrowdsale.sol";

contract OnlsSeedSale is SoftRefundableCrowdsale, AllowanceCrowdsale {

  uint256 private _usdRate;
  uint256 private _minBuy;

  modifier minimalPurchaseValue {
    require(msg.value >= _minBuy, 'minimal purchase value required');
    _;
  }

  constructor(
    address salesOwner,
    address tokenOwner,
    uint256 tokenPrice,
    uint256 usdRate,
    uint256 minGoal,
    uint256 minBuy,
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
    _usdRate = usdRate;
    _minBuy = minBuy;
  }

  function getWeiTokenPrice(uint256 amount) public view returns(uint256) {
    return rate().mul(amount);
  }

  /**
   * @dev returns price of amount of tokens in usd cents
   */
  function getUsdTokenPrice(uint256 amount) public view returns(uint256) {
    return rate().div(_usdRate).mul(amount);
  }

  function getUsdTokenAmount(uint256 usdAmount) public view returns (uint256) {
    return usdAmount.div(rate().div(_usdRate));
  }

  function getWeiTokenAmount(uint256 weiAmount) public view returns (uint256) {
    return weiAmount.div(rate());
  }

  function _calculateRate(uint256 tokenPrice, uint256 usdRate) internal pure returns (uint256) {
    return tokenPrice.mul(usdRate);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    require(weiAmount.mod(rate()) == 0, 'invalid wei value passed');
    uint256 amount = weiAmount.div(rate());
    return amount;
  }

  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal minimalPurchaseValue view {
    super._preValidatePurchase(beneficiary, weiAmount);
  }
}
