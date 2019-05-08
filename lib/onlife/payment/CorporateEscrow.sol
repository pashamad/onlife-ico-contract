pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Secondary.sol";
import "../../openzepplin/ownership/Ownable.sol";

contract CorporateEscrow is Secondary, Ownable {

  event Deposited(address indexed payer, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);

  address payable private _beneficiar;

  constructor(address payable beneficiar) public {
    _beneficiar = beneficiar;
  }

  function deposit(address payer) public onlyPrimary payable {
    uint256 amount = msg.value;

    emit Deposited(payer, amount);
  }

  function withdraw() public onlyPrimary {
    uint256 payment = address(this).balance;

    _beneficiar.transfer(payment);

    emit Withdrawn(_beneficiar, payment);
  }
}
