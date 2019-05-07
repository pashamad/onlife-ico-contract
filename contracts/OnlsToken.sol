pragma solidity ^0.5.0;

import "../lib/openzepplin/token/ERC20/ERC20.sol";
import "../lib/openzepplin/token/ERC20/ERC20Detailed.sol";

contract OnlsToken is ERC20, ERC20Detailed {

  uint8 public constant DECIMALS = 0;
  uint256 public constant INITIAL_SUPPLY = 1000000000;

  constructor (address owner) public ERC20Detailed("ONLife Sale", "ONLS", DECIMALS) {
      _mint(owner, INITIAL_SUPPLY);
  }
}