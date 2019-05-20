pragma solidity ^0.5.0;

import "../lib/onlife/crowdsale/AllowanceCrowdsale.sol";
import "../lib/onlife/crowdsale/SoftRefundableCrowdsale.sol";

contract OnlsCrowdsale is SoftRefundableCrowdsale, AllowanceCrowdsale {

  uint256 private _tokenPriceUsd;
  uint256 private _minPurchaseUsd;
  uint256 private _maxPurchaseUsd;

  uint256 private _usdRate;

  uint256 private _minPurchaseWei;
  uint256 private _maxPurchaseWei;

  modifier minimalPurchaseValue {
    require(msg.value >= _minPurchaseWei, 'minimal purchase value required');
    _;
  }

  modifier maximumPurchaseValue {
    require(msg.value <= _maxPurchaseWei, 'maximum purchase value exceeded');
    _;
  }

  event UsdRateUpdated(uint256 rate, uint256 minPurchase, uint256 maxPurchase);

  /**
    * @param salesOwner Address of the sales administrator account
    * @param tokenOwner Address of the account to which the amount of tokens has been approved
    * @param tokenPriceUsd Fixed price of token in USD cents
    * @param usdRate Exchange rate of USD cent to WEI. Can be updated after deployment.
    * @param minPurchaseUsd Minimum amount that can be spent on tokens in USD
    * @param maxPurchaseUsd Maximum amount that can be spent on tokens in USD
    * @param minGoal Minimal goal (soft cap) in WEI. Upon reaching this goal, raised funds and sold tokens can be unlocked and withdrawn.
    * @param fundsWallet Address of EOA where raised funds will be forwarded to
    * @param token Address of the token contract
    */
  constructor(
    address salesOwner,
    address tokenOwner,
    uint256 tokenPriceUsd,
    uint256 usdRate,
    uint256 minPurchaseUsd,
    uint256 maxPurchaseUsd,
    uint256 minGoal,
    address payable fundsWallet,
    IERC20 token
  ) Crowdsale(tokenPriceUsd.mul(usdRate), fundsWallet, token)
    FinalizableCrowdsale()
    AllowanceCrowdsale(tokenOwner)
    SoftRefundableCrowdsale(minGoal, salesOwner)
    public
  {
    // immutable variables
    _usdRate = usdRate;
    _tokenPriceUsd = tokenPriceUsd;
    _minPurchaseUsd = minPurchaseUsd;
    _maxPurchaseUsd = maxPurchaseUsd;

    // mutable state variables, will be updated on usd rate change
    _minPurchaseWei = _minPurchaseUsd.mul(_usdRate);
    _maxPurchaseWei = _maxPurchaseUsd.mul(_usdRate);
  }

  function updateUsdRate(uint256 usdRate) public onlyOwner {
    _usdRate = usdRate;
    _minPurchaseWei = _minPurchaseUsd.mul(_usdRate);
    _maxPurchaseWei = _maxPurchaseUsd.mul(_usdRate);

    emit UsdRateUpdated(_usdRate, _minPurchaseWei, _maxPurchaseWei);

    _updateRate(_tokenPriceUsd.mul(_usdRate));
  }

  function getUsdRate() public view returns(uint256) {
    return _usdRate;
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

  // function _calculateRate(uint256 tokenPrice, uint256 usdRate) internal pure returns (uint256) {
  //   return tokenPrice.mul(usdRate);
  // }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    require(weiAmount.mod(rate()) == 0, 'invalid wei value passed');
    uint256 amount = weiAmount.div(rate());
    return amount;
  }

  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal minimalPurchaseValue maximumPurchaseValue view {
    super._preValidatePurchase(beneficiary, weiAmount);
  }
}
