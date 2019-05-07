pragma solidity ^0.5.0;

import "./LockedDeliveryCrowdsale.sol";
import "../../openzepplin/ownership/Ownable.sol";
import "../../openzepplin/crowdsale/distribution/FinalizableCrowdsale.sol";
import "../../openzepplin/payment/escrow/RefundEscrow.sol";
import "../payment/CorporateEscrow.sol";

contract SoftRefundableCrowdsale is LockedDeliveryCrowdsale, FinalizableCrowdsale, Ownable {

    using SafeMath for uint256;

    uint256 private _goal;

    RefundEscrow private _goalEscrow;
    CorporateEscrow private _raiseEscrow;

    constructor (uint256 goal, address owner) public {
        require(goal > 0, 'requires goal > 0');

        _raiseEscrow = new CorporateEscrow(wallet());
        _raiseEscrow.transferOwnership(owner);

        // TODO: best to pass payable address of the raise escrow
        _goalEscrow = new RefundEscrow(wallet());
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

      _goalEscrow.close();
      // TODO: do we need to initate token delivery or wait for the user to do it manually?
      unlock();
      // TODO: transfer goal escrow balance to corporate escrow
      // _goalEscrow.beneficiaryWithdraw();
    }

    function claimRefund(address payable refundee) public {
      require(finalized(), 'no refunds before sale is closed');
      require(!goalReached(), 'no refunds on successful sale');

      _goalEscrow.withdraw(refundee);
      // TODO: release refundee tokens
    }

    function _finalization() internal {
      // TODO: finalization logic in case token supply has been completely sold
      if (!goalReached()) {
        _goalEscrow.enableRefunds();
      }

      super._finalization();
    }

    function _forwardFunds() internal {
      if (isLocked()) {
        _goalEscrow.deposit.value(msg.value)(msg.sender);
      } else {
        _raiseEscrow.deposit.value(msg.value)(msg.sender);
      }
    }
}
