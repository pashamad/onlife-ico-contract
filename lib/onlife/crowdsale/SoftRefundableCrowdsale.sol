pragma solidity ^0.5.0;

import "../../openzepplin/payment/escrow/RefundEscrow.sol";

import "../control/Lock.sol";
import "../payment/CorporateEscrow.sol";
import "./LockedDeliveryCrowdsale.sol";

contract SoftRefundableCrowdsale is LockedDeliveryCrowdsale {

  using SafeMath for uint256;

  uint256 private _minGoal;

  RefundEscrow private _goalEscrow;
  CorporateEscrow private _raiseEscrow;

  Lock private _fundsLock;

  constructor (uint256 minGoal, address salesOwner) public {
    require(minGoal > 0, 'requires minGoal > 0');

    _fundsLock = new Lock();
    _fundsLock.lock();

    _raiseEscrow = new CorporateEscrow(wallet());
    _raiseEscrow.transferOwnership(salesOwner);

    _goalEscrow = new RefundEscrow(wallet());
    _minGoal = minGoal;

    transferOwnership(salesOwner);
  }

  function goal() public view returns (uint256) {
    return _minGoal;
  }

  function goalReached() public view returns (bool) {
    return weiRaised() >= _minGoal;
  }

  function goalBalance() public view returns(uint256) {
    return address(_goalEscrow).balance;
  }

  function raiseBalance() public view returns(uint256) {
    return address(_raiseEscrow).balance;
  }

  function totalBalance() public view returns(uint256) {
    return goalBalance().add(raiseBalance());
  }

  function releaseFunds() public onlyOwner {
    require(_fundsLock.isLocked(), 'funds are not locked');
    require(goalReached(), 'goal must be reached to unlock');
    require(!finalized(), 'crowdsale must be open to unlock');

    _fundsLock.unlock();
    _goalEscrow.close();
  }

  function claimRefund(address payable refundee) public {
    require(finalized(), 'no refunds before sale is closed');
    require(!goalReached(), 'no refunds after soft cap');

    _goalEscrow.withdraw(refundee);
    releaseTokens(refundee);
  }

  function withdraw() public onlyOwner {
    require(!_fundsLock.isLocked(), 'funds are locked');

    if (address(_goalEscrow).balance > 0) {
      _goalEscrow.beneficiaryWithdraw();
    }

    // allows to withdraw zero balance for testing purposes
    _raiseEscrow.withdraw();
  }

  function changeBeneficiar(address payable beneficiar) public onlyOwner {
    _raiseEscrow.changeBeneficiar(beneficiar);
  }

  function _finalization() internal {
    // TODO: finalization logic in case token supply has been completely sold
    if (!goalReached()) {
      _goalEscrow.enableRefunds();
    }

    super._finalization();
  }

  function _forwardFunds() internal {
    if (_fundsLock.isLocked()) {
      _goalEscrow.deposit.value(msg.value)(msg.sender);
    } else {
      _raiseEscrow.deposit.value(msg.value)(msg.sender);
    }
  }
}
