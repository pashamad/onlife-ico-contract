pragma solidity ^0.5.0;

import "../../openzepplin/payment/escrow/RefundEscrow.sol";

import "../control/Lock.sol";
import "../payment/CorporateEscrow.sol";
import "./LockedDeliveryCrowdsale.sol";

/**
 * @title SoftRefundableCrowdsale
 * @dev Provides functionality to keep funds on goal escrow and to refund them if softcap goal has not been reached.
 * If it has, it starts to send funds to separate non-refundabe escrow.
 * Also, provides methods to refund funds after crowdsale finalized buy softcap goal not reached.
 */
contract SoftRefundableCrowdsale is LockedDeliveryCrowdsale {

  using SafeMath for uint256;

  // immutable softcap goal in wei
  uint256 private _minGoal;

  // refundable goal escrow
  RefundEscrow private _goalEscrow;
  // non-refundable raise escrow
  CorporateEscrow private _raiseEscrow;

  /**
   * @param minGoal Minimal goal to be raised (softcap) in wei
   * @param salesOwner Administrative account address
   */
  constructor (uint256 minGoal, address salesOwner) public {
    require(minGoal > 0, 'requires minGoal > 0');

    _raiseEscrow = new CorporateEscrow(wallet());
    _raiseEscrow.transferOwnership(salesOwner);

    _goalEscrow = new RefundEscrow(wallet());
    _minGoal = minGoal;

    transferOwnership(salesOwner);
  }

  /**
   * @return softcap goal set in the contract
   */
  function goal() public view returns (uint256) {
    return _minGoal;
  }

  /**
   * @return true if softcap goal has been reached, false otherwise
   */
  function goalReached() public view returns (bool) {
    return weiRaised() >= _minGoal;
  }

  /**
   * @dev Returns the balance of refundable goal escrow
   * @return goal balance in wei
   */
  function goalBalance() public view returns(uint256) {
    return address(_goalEscrow).balance;
  }

  /**
   * @dev Returns the balance of non-refundable raise escrow
   * @return raise balance in wei
   */
  function raiseBalance() public view returns(uint256) {
    return address(_raiseEscrow).balance;
  }

  /**
   * @dev Returns cumulative balance of both goal and raise escrow
   * @return total balance in wei
   */
  function totalBalance() public view returns(uint256) {
    return goalBalance().add(raiseBalance());
  }

  /**
   * @dev Allows to unlock funds after reaching softcap. This means that raised funds can be withdrawn to corporate wallet;
   * also tokens can be withdrawn by purchasers to their accounts, provided by parent LockedDeliveryCrowdsale class.
   * Only owner can call this method.
   */
  function unlockFunds() public onlyOwner {
    require(goalReached(), 'goal must be reached to unlock funds');
    unlockState();

    _goalEscrow.close();
  }

  /**
   * @dev Allows to refund funds by purchaser after crowdsale has been finalized but the softcap goal has not been reached.
   * @param refundee purchaser address
   */
  function claimRefund(address payable refundee) public {
    require(finalized(), 'no refunds allowed before crowdsale is closed');
    require(!goalReached(), 'no refunds allowed after successful softcap');

    _goalEscrow.withdraw(refundee);
    releaseTokens(refundee);
  }

  /**
   * @dev Allows owner to withdraw all raised funds to corporate wallet. Only possible after softcap has been reached.
   */
  function withdraw() public onlyOwner {
    require(!isLocked(), 'crowdsale is in locked state');

    if (address(_goalEscrow).balance > 0) {
      _goalEscrow.beneficiaryWithdraw();
    }

    // allows to withdraw zero balance
    _raiseEscrow.withdraw();
  }

  /**
   * @dev Allows owner to change corporate wallet address.
   * @param beneficiar wallet address to send raised funds to
   */
  function changeBeneficiar(address payable beneficiar) public onlyOwner {
    _raiseEscrow.changeBeneficiar(beneficiar);
  }

  /**
   * @dev Finalization logic. If the softcap is not hit, enable refunds on the goal escrow.
   */
  function _finalization() internal {
    if (!goalReached()) {
      _goalEscrow.enableRefunds();
    }

    super._finalization();
  }

  /**
   * @dev Forwards funds from token purchases to either goal escrow or raise escrow, depending on whether contract state is unlocked.
   */
  function _forwardFunds() internal {
    if (isLocked()) {
      _goalEscrow.deposit.value(msg.value)(msg.sender);
    } else {
      _raiseEscrow.deposit.value(msg.value)(msg.sender);
    }
  }
}
