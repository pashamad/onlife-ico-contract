pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/token/ERC20/ERC20Mintable.sol";

contract ONLSTestToken is ERC20Mintable {
  string public constant name = "ONLS Test Token";
  string public constant symbol = "ONLST";
  uint8 public constant decimals = 4;
}
