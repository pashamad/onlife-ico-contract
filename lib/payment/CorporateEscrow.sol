pragma solidity ^0.5.0;

import "../ownership/Secondary.sol";
import "../ownership/Ownable.sol";

/**
 * @title CorporateEscrow
 * @dev Corporate escrow to hold funds before withdrawal to corporate wallet
 */
contract CorporateEscrow is Secondary, Ownable {

  event Deposited(address indexed payer, uint256 weiAmount);
  event Withdrawn(address indexed payee, uint256 weiAmount);
  event BeneficiarChanged(address indexed beneficiar);

  address payable private _beneficiar;

  constructor(address payable beneficiar) public {
    _beneficiar = beneficiar;
  }

  /**
   * @dev Put some funds to the escrow. Emit Deposited event.
   * @param payer payer address
   */
  function deposit(address payer) public onlyPrimary payable {
    uint256 amount = msg.value;

    emit Deposited(payer, amount);
  }

  /**
   * @dev Withdraw funds to stored wallet address. Emits Withdrawn event.
   */
  function withdraw() public onlyPrimary {
    uint256 payment = address(this).balance;

    _beneficiar.transfer(payment);

    emit Withdrawn(_beneficiar, payment);
  }

  /**
   * @dev Change beneficiar wallet address. Emits BeneficiarChanged event.
   */
  function changeBeneficiar(address payable beneficiar) public onlyPrimary {
    require(beneficiar != address(0), 'invalid beneficiar address');
    require(beneficiar != _beneficiar, 'beneficiar address is unchaged');

    _beneficiar = beneficiar;

    emit BeneficiarChanged(_beneficiar);
  }
}
