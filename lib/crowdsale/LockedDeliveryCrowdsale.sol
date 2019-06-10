pragma solidity ^0.5.0;

import "./FinalizableCrowdsale.sol";
import "../control/Lock.sol";

/**
 * @title LockedDeliveryCrowdsale
 * @dev Provides functionality fo holding tokens sold and funds raised in the contract.
 * Will revert transaction that is trying to withdraw tokens while crowdsale is in locked state.
 * Once the contract has been unlocked, tokens can be withdrawn to purchased wallet.
 * It also provides locked state functionality to deriving classes.
 */
contract LockedDeliveryCrowdsale is FinalizableCrowdsale {
  using SafeMath for uint256;

  // internal token balances of token purchasers
  mapping(address => uint256) private _balances;

  Lock private _stateLock;

  modifier onlyWhenUnlocked() {
    require(!_stateLock.isLocked(), 'crowdsale is in locked state');
    _;
  }

  /**
   * @dev locks crowdsale on creation
   */
  constructor() internal {
    _stateLock = new Lock();
    _stateLock.lock();
  }

  /**
   * @dev Unlocks contract state. This is a one-way operation, meaning that once unlocked, state can not be locked back.
   * Only owner can unlock it, and only if the contract has not been finalized.
   */
  function unlockState() internal onlyOwner {
    require(_stateLock.isLocked(), 'crowdsale is not in locked state');
    require(!finalized(), 'crowdsale must not be finalized to unlock');

    _stateLock.unlock();
  }

  /**
   * @dev Try to withdraw tokens to purchaser account and reset its internal balance to 0. Guarded by onlyWhenUnlocked modifier.
   * @param beneficiary purchaser account
   */
  function withdrawTokens(address beneficiary) public onlyWhenUnlocked {
    uint256 amount = _balances[beneficiary];
    require(amount > 0, 'requires positive amount');
    _balances[beneficiary] = 0;
    _deliverTokens(beneficiary, amount);
  }

  /**
   * @dev Allows to reset purchaser account without withdrawing tokens, if the sale has been finalized. Guarded by onlyOwner modifier.
   * Required for situation when crowdsale is locked but in refund state (specifically, when softcap has not been reached in a long period of time).
   * I.e. - this method should be called when purchaser requested refund and after funds has been succesfully refunded to him.
   * @param beneficiary address of tokens purchaser
   */
  function releaseTokens(address beneficiary) internal onlyOwner {
    require(finalized(), 'no refunds allowed before sale is closed');
    _balances[beneficiary] = 0;
  }

  /**
   * @dev Returns internal balance of specific account.
   * @param account address of token purchaser account
   * @return purchaser balance
   */
  function balanceOf(address account) public view returns (uint256) {
    return _balances[account];
  }

  /**
   * @dev Returns lock state of the contract.
   * @return lock state
   */
  function isLocked() public view returns (bool) {
    return _stateLock.isLocked();
  }

  /**
   * @dev Implements token purchase without actually transferring tokens to purchaser account.
   * Once the contract is unlocked, it start to send tokens directly through the parent method.
   * @param beneficiary purchaser account address
   * @param tokenAmount amount of tokens purchased
   */
  function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
    if (isLocked()) {
      _balances[beneficiary] = _balances[beneficiary].add(tokenAmount);
    } else {
      _deliverTokens(beneficiary, tokenAmount);
    }
  }
}
