pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";

contract ONLSMintableToken is ERC20Mintable {
  string public constant name = "ONLS Mintable Token";
  string public constant symbol = "ONLSMT";
  uint8 public constant decimals = 18;
}
