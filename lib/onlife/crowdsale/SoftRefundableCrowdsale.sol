pragma solidity ^0.5.0;

import "./LockedDeliveryCrowdsale.sol";
import "../../openzepplin/ownership/Ownable.sol";
import "../payment/UnlockableRefundEscrow.sol";

contract SoftRefundableCrowdsale is LockedDeliveryCrowdsale, Ownable {

    using SafeMath for uint256;

    uint256 private _goal;

    UnlockableRefundEscrow private _escrow;

    constructor (uint256 goal) public {
        require(goal > 0, 'requires goal > 0');
        _escrow = new UnlockableRefundEscrow(wallet());
        _goal = goal;
    }

    function goal() public view returns (uint256) {
        return _goal;
    }
    function goalReached() public view returns (bool) {
        return weiRaised() >= _goal;
    }

    function release() public onlyOwner {
      require(goalReached(), 'goal must be reached to unlock');
      require(isOpen(), 'crowdsale must be open to unlock');
    }

    function _finalization() internal {
        if (goalReached()) {
            _escrow.unlock();
            _escrow.transferPrimary(wallet());
        } else {
            _escrow.enableRefunds();
        }
    }

    function _forwardFunds() internal {
        _escrow.deposit.value(msg.value)(msg.sender);
    }
}
