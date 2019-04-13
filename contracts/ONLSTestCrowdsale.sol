pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/crowdsale/emission/MintedCrowdsale.sol";
import "../node_modules/openzeppelin-solidity/contracts/crowdsale/distribution/RefundableCrowdsale.sol";
import "../node_modules/openzeppelin-solidity/contracts/crowdsale/validation/CappedCrowdsale.sol";
import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";

contract ONLSTestCrowdsale is CappedCrowdsale, RefundableCrowdsale, MintedCrowdsale {

 constructor(
  uint256 _openingTime,
  uint256 _closingTime,
  uint256 _rate,
  address payable _wallet,
  uint256 _cap,
  ERC20Mintable _token,
  uint256 _goal
 )
  public Crowdsale(_rate, _wallet, _token)
  CappedCrowdsale(_cap)
  TimedCrowdsale(_openingTime, _closingTime)
  RefundableCrowdsale(_goal)
 {
  require(_goal <= _cap);
 }
}
