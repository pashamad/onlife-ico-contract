pragma solidity ^0.5.0;

import "../math/SafeMath.sol";
import "./Crowdsale.sol";

/**
 * @title TimedCrowdsale
 * @dev Crowdsale accepting contributions only within a time frame.
 */
contract TimedCrowdsale is Crowdsale {
  using SafeMath for uint256;

  uint256 private _closingTime;

  /**
    * @dev Reverts if not in crowdsale time range.
    */
  modifier onlyWhileOpen {
    require(isOpen(), "TimedCrowdsale: not open");
    _;
  }

  /**
    * @dev Constructor, takes crowdsale duration time.
    * @param duration Crowdsale duration time in seconds
    */
  constructor (uint256 duration) public {
    // solhint-disable-next-line not-rely-on-time
    _closingTime = block.timestamp.add(duration);
  }

  /**
    * @return the crowdsale closing time.
    */
  function closingTime() public view returns (uint256) {
    return _closingTime;
  }

  /**
    * @return true if the crowdsale is open, false otherwise.
    */
  function isOpen() public view returns (bool) {
    // solhint-disable-next-line not-rely-on-time
    return block.timestamp <= _closingTime;
  }

  /**
    * @dev Checks whether the period in which the crowdsale is open has already elapsed.
    * @return Whether crowdsale period has elapsed
    */
  function hasClosed() public view returns (bool) {
    // solhint-disable-next-line not-rely-on-time
    return block.timestamp > _closingTime;
  }

  /**
    * @dev Extend parent behavior requiring to be within contributing period.
    * @param beneficiary Token purchaser
    * @param weiAmount Amount of wei contributed
    */
  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal onlyWhileOpen view {
    super._preValidatePurchase(beneficiary, weiAmount);
  }
}
