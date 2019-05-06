pragma solidity ^0.5.0;

import "../../openzepplin/payment/escrow/RefundEscrow.sol";
import "../control/Lockable.sol";

contract UnlockableRefundEscrow is RefundEscrow, Lockable {

  using SafeMath for uint256;

  mapping(address => uint256) private _balances;

  constructor(address payable beneficiary) public RefundEscrow(beneficiary) {
    //
  }

  function withdrawalAllowed(address payee) public view returns (bool) {
    return isLocked() ? super.withdrawalAllowed(payee) : true;
  }
}
