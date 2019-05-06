pragma solidity ^0.5.0;

import "../../openzepplin/crowdsale/validation/TimedCrowdsale.sol";
import "../control/Lockable.sol";

contract LockedDeliveryCrowdsale is TimedCrowdsale, Lockable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    function withdrawTokens(address beneficiary) public {
        require(!isLocked(), 'crowdsale is locked');
        uint256 amount = _balances[beneficiary];
        require(amount > 0, 'requires positive amount');
        _balances[beneficiary] = 0;
        _deliverTokens(beneficiary, amount);
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        _balances[beneficiary] = _balances[beneficiary].add(tokenAmount);
    }

}
