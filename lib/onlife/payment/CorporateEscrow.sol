pragma solidity ^0.5.0;

import "../../openzepplin/ownership/Secondary.sol";
import "../../openzepplin/ownership/Ownable.sol";

/**
 * @dev corporate escrow to hold funds before withdrawal to corporate wallet
 *
 * @dev in case to be able to allow more flex access control to deposit and withdraw methods,
 * it should be deployed as a standalone contract; then the list of depositors and the owner
 * can hold different addresses; also, it would make it possible to attach one escrow to
 * different contracts
 */
contract CorporateEscrow is Secondary, Ownable {

  event Deposited(address indexed payer, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);
  event BeneficiarChanged(address indexed beneficiar);

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

  function changeBeneficiar(address payable beneficiar) public onlyPrimary {
    require(beneficiar != address(0), 'invalid beneficiar address');
    require(beneficiar != _beneficiar, 'beneficiar address is unchaged');

    _beneficiar = beneficiar;

    emit BeneficiarChanged(_beneficiar);
  }
}
