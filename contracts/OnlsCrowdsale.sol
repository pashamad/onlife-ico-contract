pragma solidity ^0.5.0;

import "../lib/crowdsale/AllowanceCrowdsale.sol";
import "../lib/crowdsale/SoftRefundableCrowdsale.sol";
import "./OnlsToken.sol";

/**
  * @title OnlsCrowdsale
  * @dev Main crowdsale contract. Base features:
  * - does not transfer tokens to the contract account, but approves respective amount to be sold
  * - implements post-delivery functionality, meaning that tokens are not transfered to purchaser account
  *   right away, but instead are put to purchaser balance inside the contract
  * - locks collected funds and sold tokens, disallowing to withdraw them while in locked state
  * - sets immutable softcap in wei, which must be reached before contract can be unlocked
  * - creates two escrow contracts to accumulate collected funds
  * - before reaching softcap, funds will be held on "goal" escrow
  * - after reaching softcap, funds will be held on "raise" escrow
  * - provides method for manual unlocking after reaching softcap; if softcap has not been reached, unlock will not be possible
  * - after unlocking, tokens can be withdrawn to purchaser account; respectively, raised funds can be withdrawn to corporate account
  * - allows to finalize crowdsale, thus closing it in a way that tokens can't be bought anymore
  * - if the softcap has not been reached, finalized crowdsale allows to refund collected funds and return sold tokens to owner account
  * - sets corporate wallet address upon deployment; this is the account where raised funds will be sent to on withdrawal
  * - allows to update corporate wallet address
  * - sets token price in wei based on exchange rate of usd to eth
  * - sets minimum and maximum purchase allowances based on exchange rate of usd to eth
  * - allows to update exchange rate of usd to eth; token wei price, minimum and maximum purchase values will be updated as per new rate
  */
contract OnlsCrowdsale is SoftRefundableCrowdsale, AllowanceCrowdsale {

  // immutable price of token in usd cents
  uint256 private _tokenPriceUsd;
  // immutable minimum purchase threshold in usd cents
  uint256 private _minPurchaseUsd;
  // immutable maximum purchase threshold in usd cents
  uint256 private _maxPurchaseUsd;

  // mutable rate of usd cent to wei
  uint256 private _usdRate;

  // mutable min-max purchase thresholds in wei; re-calculated every time when usd rate is updated
  uint256 private _minPurchaseWei;
  uint256 private _maxPurchaseWei;

  // minimal purchase guard
  modifier minimalPurchaseValue {
    require(msg.value >= _minPurchaseWei, 'minimal purchase value required');
    _;
  }

  // maximum purchase guard
  modifier maximumPurchaseValue {
    uint256 spent = balanceOf(msg.sender).mul(rate());
    spent = spent.add(token().balanceOf(msg.sender).mul(rate()));
    require(spent.add(msg.value) <= _maxPurchaseWei, 'maximum purchase value exceeded');
    _;
  }

  /**
   * @dev Emits upon successful usd rate update
   * @param rate new rate in wei per cent
   * @param minPurchase new value of minimal purchase in wei
   * @param maxPurchase new value of maximum purchase in wei
   */
  event UsdRateUpdated(uint256 rate, uint256 minPurchase, uint256 maxPurchase);

  /**
    * @param salesOwner Address of the sales administrator account
    * @param tokenOwner Address of the account to which the amount of tokens has been approved
    * @param tokenPriceUsd Fixed price of token in USD cents
    * @param usdRate Exchange rate of USD cent to WEI. Can be updated after deployment.
    * @param minPurchaseUsd Minimum amount that can be spent on tokens in USD
    * @param maxPurchaseUsd Maximum amount that can be spent on tokens in USD
    * @param minGoal Minimal goal (soft cap) in WEI. Upon reaching this goal, raised funds and sold tokens can be unlocked and withdrawn.
    * @param duration Maximum duration of crowdsale in seconds
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
    uint256 duration,
    address payable fundsWallet,
    OnlsToken token
  ) Crowdsale(tokenPriceUsd.mul(usdRate).div(10 ** uint256(token.decimals())), fundsWallet, token)
    FinalizableCrowdsale()
    TimedCrowdsale(duration)
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
    _minPurchaseWei = _minPurchaseUsd.div(_tokenPriceUsd).mul(rate()).mul(10 ** uint256(token.decimals()));
    _maxPurchaseWei = _maxPurchaseUsd.div(_tokenPriceUsd).mul(rate()).mul(10 ** uint256(token.decimals()));
  }

  /**
   * @dev Updates exchange rate of usd to eth. Rate is set in amount of wei per 1 usd cent.
   * Also updates minPurchase and maxPurchase state variables, and emits UsdRateUpdated event.
   * @param usdRate Cost in wei per usd cent
   */
  function updateUsdRate(uint256 usdRate) public onlyOwner {
    _usdRate = usdRate;
    _updateRate(_tokenPriceUsd.mul(_usdRate).div(10 ** uint256(token().decimals())));

    _minPurchaseWei = _minPurchaseUsd.div(_tokenPriceUsd).mul(rate()).mul(10 ** uint256(token().decimals()));
    _maxPurchaseWei = _maxPurchaseUsd.div(_tokenPriceUsd).mul(rate()).mul(10 ** uint256(token().decimals()));

    emit UsdRateUpdated(_usdRate, _minPurchaseWei, _maxPurchaseWei);
  }

  /**
   * @dev Returns usd to eth rate stored in contract state
   * @return rate in wei per usd cent
   */
  function getUsdRate() public view returns(uint256) {
    return _usdRate;
  }

  /**
   * @dev Returns price needs to be paid for specific amount of tokens
   * @return tokens value in wei
   */
  function getWeiTokenPrice(uint256 amount) public view returns(uint256) {
    return rate().mul(amount);
  }

  /**
   * @dev Returns price of amount of tokens in usd cents
   * @param amount amount of tokens
   * @return price of specified amount in usd cents
   */
  function getUsdTokenPrice(uint256 amount) public view returns(uint256) {
    return _tokenPriceUsd.mul(amount);
  }

  /**
   * @dev Returns amount of tokens that can be purchased for specified amount of wei
   * @param weiAmount value in wei
   * @return amount of tokens
   */
  function getWeiTokenAmount(uint256 weiAmount) public view returns (uint256) {
    return _getTokenAmount(weiAmount);
  }

  /**
   * @dev Returns amount of tokens that can be purchased for specified amount of usd cents
   * @param usdAmount value in usd cents
   * @return amount of tokens
   */
  function getUsdTokenAmount(uint256 usdAmount) public view returns (uint256) {
    return usdAmount.div(_tokenPriceUsd);
  }

  function getMinPurchaseWei() public view returns (uint256) {
    return _minPurchaseWei;
  }

  function getMaxPurchaseWei() public view returns (uint256) {
    return _maxPurchaseWei;
  }

  /**
   * @dev Internal implementation of getWeiTokenAmount public method.
   * IMPORTANT: this method returns amount in smallest token units, which is defined by a decimal token part.
   * This behaviour differs from public methods that return amount of whole tokens that can be bought for passed amount of wei.
   * @param weiAmount value in wei
   * @return amount of tokens
   */
  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    uint256 amount = weiAmount.div(rate());
    // if the amount wei is not exact multiple of token rate, adds one token on top
    if (weiAmount.mod(rate()) != 0) {
      amount += 1;
    }
    return amount;
  }

  /**
   * @dev Provides modifier guards for minimum and maximum allowed purchase values
   */
  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal minimalPurchaseValue maximumPurchaseValue view {
    super._preValidatePurchase(beneficiary, weiAmount);
  }
}
