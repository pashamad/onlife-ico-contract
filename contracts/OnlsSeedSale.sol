pragma solidity ^0.5.0;

import "../lib/openzepplin/crowdsale/emission/AllowanceCrowdsale.sol";
import "../lib/openzepplin/crowdsale/distribution/RefundablePostDeliveryCrowdsale.sol";
import "../lib/openzepplin/crowdsale/validation/TimedCrowdsale.sol";

contract OnlsSeedSale is AllowanceCrowdsale, RefundablePostDeliveryCrowdsale {

  constructor(
    address tokenWallet,
    uint256 tokenPrice,
    uint256 usdRate,
    uint256 goal,
    uint256 openingTime,
    uint256 closingTime,
    address payable targetWallet,
    IERC20 token
  ) public
    AllowanceCrowdsale(tokenWallet)
    RefundableCrowdsale(goal)
    TimedCrowdsale(openingTime, closingTime)
    Crowdsale(_calculateRate(tokenPrice, usdRate), targetWallet, token) {
      //
    }

  function _calculateRate(uint256 tokenPrice, uint256 usdRate) internal pure returns (uint256) {
    return tokenPrice.mul(usdRate);
  }

  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    uint256 amount = weiAmount.div(rate());
    require(weiAmount.mod(rate()) == 0, 'invalid wei value passed');
    return amount;
  }

  function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
    super._processPurchase(beneficiary, tokenAmount);
    // TODO: can send remaining wei back to the sender in case wei value is not multiple to the rate
    // uint256 remainder = (msg.value).mod(rate());
    // (msg.sender).transfer(remainder);
  }
}
