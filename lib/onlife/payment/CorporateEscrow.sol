pragma solidity ^0.5.0;

import "../../openzepplin/math/SafeMath.sol";
import "../../openzepplin/ownership/Secondary.sol";
import "../../openzepplin/ownership/Ownable.sol";

contract CorporateEscrow is Secondary, Ownable {
  using SafeMath for uint256;

  event Deposited(address indexed payer, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);

  uint256 private _deposit;
  address payable private _beneficiar;

  constructor(address payable beneficiar) public {
    _beneficiar = beneficiar;
  }

  function depositAmound() public view returns (uint256) {
      return _deposit;
  }

  function deposit(address payer) public onlyPrimary payable {
    uint256 amount = msg.value;
    _deposit.add(amount);

    emit Deposited(payer, amount);
  }

  function withdraw() public onlyOwner {
    uint256 payment = _deposit;
    _deposit = 0;

    _beneficiar.transfer(payment);

    emit Withdrawn(_beneficiar, payment);
  }
}
