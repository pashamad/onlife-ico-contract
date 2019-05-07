pragma solidity ^0.5.0;

import "../../openzepplin/payment/escrow/Escrow.sol";
import "../control/Lockable.sol";

contract LockedEscrow is Escrow, Lockable {

  using SafeMath for uint256;

  uint256 _balance;
  address payable private _beneficiary;

  constructor(address payable beneficiary) public Escrow() {
    _beneficiary = beneficiary;
  }

  // TODO: this override is probably not neccessary due to onlyPrimary modifier
  function deposit(address) public onlyPrimary payable {
    require(false, 'direct diposits not allowed');
  }

  function deposit() public onlyPrimary payable {
    super.deposit(_beneficiary);
  }

  // TODO: do we need to pass amount to withdraw or just withdraw all available balance?
  function beneficiaryWithdraw() public onlyPrimary {
    require(!isLocked(), 'escrow is locked');
    _beneficiary.transfer(address(this).balance);
  }
}
