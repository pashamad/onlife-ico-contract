pragma solidity ^0.5.0;


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
}


/**
 * @title SafeMath
 * @dev Unsigned math operations with safety checks that revert on error
 */
library SafeMath {
    /**
    * @dev Multiplies two unsigned integers, reverts on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
    * @dev Integer division of two unsigned integers truncating the quotient, reverts on division by zero.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, 'division by 0');
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
    * @dev Subtracts two unsigned integers, reverts on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, 'subtraction overflow');
        uint256 c = a - b;

        return c;
    }

    /**
    * @dev Adds two unsigned integers, reverts on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, 'addition overflow');

        return c;
    }

    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, 'division by 0 in mod function');
        return a % b;
    }
}


/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure.
 * To use this library you can add a `using SafeERC20 for ERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using SafeMath for uint256;

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), 'failed to safely transfer tokens');
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require((value == 0) || (token.allowance(address(this), spender) == 0), 'safe approve check failed');
        require(token.approve(spender, value), 'safe approve failed');
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).add(value);
        require(token.approve(spender, newAllowance), 'safe allowance increase failed');
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender).sub(value);
        require(token.approve(spender, newAllowance), 'safe allowance decrease failed');
    }
}


/**
 * @title Helps contracts guard against reentrancy attacks.
 * @author Remco Bloemen <remco@2π.com>, Eenae <alexey@mixbytes.io>
 * @dev If you mark a function `nonReentrant`, you should also
 * mark it `external`.
 */
contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor () internal {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(localCounter == _guardCounter);
    }
}


/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conform
 * the base architecture for crowdsales. They are *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of crowdsales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
contract Crowdsale is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The token being sold
    IERC20 private _token;

    // Address where funds are collected
    address payable private _wallet;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    // Amount of wei raised
    uint256 private _weiRaised;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    event TokenRateUpdated(uint256 rate);

    /**
     * @param rate Number of token units a buyer gets per wei
     * @dev The rate is the conversion between wei and the smallest and indivisible
     * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
     * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
     * @param wallet Address where collected funds will be forwarded to
     * @param token Address of the token being sold
     */
    constructor (uint256 rate, address payable wallet, IERC20 token) public {
        require(rate > 0, 'invalid rate');
        require(wallet != address(0), 'invalid funds wallet address');
        require(address(token) != address(0), 'invalid token address');

        _rate = rate;
        _wallet = wallet;
        _token = token;
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer fund with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    function () external payable {
        buyTokens(msg.sender);
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return _token;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per wei.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of wei raised.
     */
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary) public nonReentrant payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        _weiRaised = _weiRaised.add(weiAmount);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(msg.sender, beneficiary, weiAmount, tokens);

        _updatePurchasingState(beneficiary, weiAmount);

        _forwardFunds();
        _postValidatePurchase(beneficiary, weiAmount);
    }

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * Example from CappedCrowdsale.sol's _preValidatePurchase method:
     *     super._preValidatePurchase(beneficiary, weiAmount);
     *     require(weiRaised().add(weiAmount) <= cap);
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(beneficiary != address(0), 'invalid beneficiary address');
        require(weiAmount != 0, 'purchase value must be > 0');
    }

    /**
     * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
     * conditions are not met.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _postValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.safeTransfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @dev Override for extensions that require an internal state to check for validity (current user contributions,
     * etc.)
     * @param beneficiary Address receiving the tokens
     * @param weiAmount Value in wei involved in the purchase
     */
    function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(_rate);
    }

    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }

    function _updateRate(uint256 newRate) internal {
      _rate = newRate;

      emit TokenRateUpdated(_rate);
    }
}


/**
 * @title Math
 * @dev Assorted math operations
 */
library Math {
    /**
    * @dev Returns the largest of two numbers.
    */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
    * @dev Returns the smallest of two numbers.
    */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
    * @dev Calculates the average of two numbers. Since these are integers,
    * averages of an even and odd number cannot be represented, and will be
    * rounded down.
    */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}


/**
 * @title AllowanceCrowdsale
 * @dev Extension of Crowdsale where tokens are held by a wallet, which approves an allowance to the crowdsale.
 */
contract AllowanceCrowdsale is Crowdsale {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address private _tokenWallet;

    /**
     * @dev Constructor, takes token wallet address.
     * @param tokenWallet Address holding the tokens, which has approved allowance to the crowdsale
     */
    constructor (address tokenWallet) public {
        require(tokenWallet != address(0), 'invalid token wallet address');
        _tokenWallet = tokenWallet;
    }

    /**
     * @return the address of the wallet that will hold the tokens.
     */
    function tokenWallet() public view returns (address) {
        return _tokenWallet;
    }

    /**
     * @dev Checks the amount of tokens left in the allowance.
     * @return Amount of tokens left in the allowance
     */
    function remainingTokens() public view returns (uint256) {
        return Math.min(token().balanceOf(_tokenWallet), token().allowance(_tokenWallet, address(this)));
    }

    /**
     * @dev Overrides parent behavior by transferring tokens from wallet.
     * @param beneficiary Token purchaser
     * @param tokenAmount Amount of tokens purchased
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        token().safeTransferFrom(_tokenWallet, beneficiary, tokenAmount);
    }
}


/**
 * @title Secondary
 * @dev A Secondary contract can only be used by its primary account (the one that created it)
 */
contract Secondary {
    address private _primary;

    event PrimaryTransferred(
        address recipient
    );

    /**
     * @dev Sets the primary account to the one that is creating the Secondary contract.
     */
    constructor () internal {
        _primary = msg.sender;
        emit PrimaryTransferred(_primary);
    }

    /**
     * @dev Reverts if called from any account other than the primary.
     */
    modifier onlyPrimary() {
        require(msg.sender == _primary, 'only primary allowed');
        _;
    }

    /**
     * @return the address of the primary.
     */
    function primary() public view returns (address) {
        return _primary;
    }

    /**
     * @dev Transfers contract to a new primary.
     * @param recipient The address of new primary.
     */
    function transferPrimary(address recipient) public onlyPrimary {
        require(recipient != address(0), 'invalid address of new primary');
        _primary = recipient;
        emit PrimaryTransferred(_primary);
    }
}


 /**
 * @title Escrow
 * @dev Base escrow contract, holds funds designated for a payee until they
 * withdraw them.
 * @dev Intended usage: This contract (and derived escrow contracts) should be a
 * standalone contract, that only interacts with the contract that instantiated
 * it. That way, it is guaranteed that all Ether will be handled according to
 * the Escrow rules, and there is no need to check for payable functions or
 * transfers in the inheritance tree. The contract that uses the escrow as its
 * payment method should be its primary, and provide public methods redirecting
 * to the escrow's deposit and withdraw.
 */
contract Escrow is Secondary {
    using SafeMath for uint256;

    event Deposited(address indexed payee, uint256 weiAmount);
    event Withdrawn(address indexed payee, uint256 weiAmount);

    mapping(address => uint256) private _deposits;

    function depositsOf(address payee) public view returns (uint256) {
        return _deposits[payee];
    }

    /**
    * @dev Stores the sent amount as credit to be withdrawn.
    * @param payee The destination address of the funds.
    */
    function deposit(address payee) public onlyPrimary payable {
        uint256 amount = msg.value;
        _deposits[payee] = _deposits[payee].add(amount);

        emit Deposited(payee, amount);
    }

    /**
    * @dev Withdraw accumulated balance for a payee.
    * @param payee The address whose funds will be withdrawn and transferred to.
    */
    function withdraw(address payable payee) public onlyPrimary {
        uint256 payment = _deposits[payee];

        _deposits[payee] = 0;

        payee.transfer(payment);

        emit Withdrawn(payee, payment);
    }
}


/**
 * @title ConditionalEscrow
 * @dev Base abstract escrow to only allow withdrawal if a condition is met.
 * @dev Intended usage: See Escrow.sol. Same usage guidelines apply here.
 */
contract ConditionalEscrow is Escrow {
    /**
    * @dev Returns whether an address is allowed to withdraw their funds. To be
    * implemented by derived contracts.
    * @param payee The destination address of the funds.
    */
    function withdrawalAllowed(address payee) public view returns (bool);

    function withdraw(address payable payee) public {
        require(withdrawalAllowed(payee), 'withdrawal not allowed');
        super.withdraw(payee);
    }
}


/**
 * @title RefundEscrow
 * @dev Escrow that holds funds for a beneficiary, deposited from multiple
 * parties.
 * @dev Intended usage: See Escrow.sol. Same usage guidelines apply here.
 * @dev The primary account (that is, the contract that instantiates this
 * contract) may deposit, close the deposit period, and allow for either
 * withdrawal by the beneficiary, or refunds to the depositors. All interactions
 * with RefundEscrow will be made through the primary contract. See the
 * RefundableCrowdsale contract for an example of RefundEscrow’s use.
 */
contract RefundEscrow is ConditionalEscrow {
    enum State { Active, Refunding, Closed }

    event RefundsClosed();
    event RefundsEnabled();

    State private _state;
    address payable private _beneficiary;

    /**
     * @dev Constructor.
     * @param beneficiary The beneficiary of the deposits.
     */
    constructor (address payable beneficiary) public {
        require(beneficiary != address(0), 'invalid escrow beneficiary address');
        _beneficiary = beneficiary;
        _state = State.Active;
    }

    /**
     * @return the current state of the escrow.
     */
    function state() public view returns (State) {
        return _state;
    }

    /**
     * @return the beneficiary of the escrow.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @dev Stores funds that may later be refunded.
     * @param refundee The address funds will be sent to if a refund occurs.
     */
    function deposit(address refundee) public payable {
        require(_state == State.Active, 'escrow state must be active to deposit');
        super.deposit(refundee);
    }

    /**
     * @dev Allows for the beneficiary to withdraw their funds, rejecting
     * further deposits.
     */
    function close() public onlyPrimary {
        require(_state == State.Active, 'escrow state must be active to be closed');
        _state = State.Closed;
        emit RefundsClosed();
    }

    /**
     * @dev Allows for refunds to take place, rejecting further deposits.
     */
    function enableRefunds() public onlyPrimary {
        require(_state == State.Active, 'escrow state must be active to enable refunds');
        _state = State.Refunding;
        emit RefundsEnabled();
    }

    /**
     * @dev Withdraws the beneficiary's funds.
     */
    function beneficiaryWithdraw() public {
        require(_state == State.Closed, 'escrow state must be closed for beneficiary to withdraw funds');
        _beneficiary.transfer(address(this).balance);
    }

    /**
     * @dev Returns whether refundees can withdraw their deposits (be refunded). The overriden function receives a
     * 'payee' argument, but we ignore it here since the condition is global, not per-payee.
     */
    function withdrawalAllowed(address) public view returns (bool) {
        return _state == State.Refunding;
    }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev The Ownable constructor sets the original `owner` of the contract to the sender
     * account.
     */
    constructor () internal {
        _owner = msg.sender;
        emit OwnershipTransferred(address(0), _owner);
    }

    /**
     * @return the address of the owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), 'only owner allowed');
        _;
    }

    /**
     * @return true if `msg.sender` is the owner of the contract.
     */
    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    /**
     * @dev Allows the current owner to relinquish control of the contract.
     * @notice Renouncing to ownership will leave the contract without an owner.
     * It will not be possible to call the functions with the `onlyOwner`
     * modifier anymore.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), 'invalid address of new owner');
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}


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


/**
 * @title FinalizableCrowdsale
 * @dev Provides finalized state for derived contracts, as well as a method to define some finalization logic.
 */
contract FinalizableCrowdsale is Crowdsale, Ownable {
    using SafeMath for uint256;

    bool private _finalized;

    event CrowdsaleFinalized();

    constructor () internal {
        _finalized = false;
    }

    /**
     * @return true if the crowdsale is finalized, false otherwise.
     */
    function finalized() public view returns (bool) {
        return _finalized;
    }

    /**
     * @dev Switches crowdsale to finalized state. Only owner can call this method. Emits CrowdsaleFinalized event.
     */
    function finalize() public onlyOwner {
        require(!_finalized, 'crowdsale already finalized');

        _finalized = true;

        _finalization();
        emit CrowdsaleFinalized();
    }

    /**
     * @dev Can be overridden to add finalization logic. The overriding function
     * should call super._finalization() to ensure the chain of finalization is
     * executed entirely.
     */
    function _finalization() internal {
        // solhint-disable-previous-line no-empty-blocks
    }
}


/**
 * @title Lock
 * @dev Basic lock contract
 */
contract Lock is Secondary {

  enum LockState { Locked, Unlocked }

  event LockStateChanged(LockState state);

  LockState private _state;

  constructor() public {
    _state = LockState.Unlocked;
  }

  function isLocked() public view returns (bool) {
    return _state == LockState.Locked;
  }

  function lock() public onlyPrimary {
    require(_state == LockState.Unlocked, 'already locked');
    _state = LockState.Locked;

    emit LockStateChanged(LockState.Locked);
  }

  function unlock() public onlyPrimary {
    require(_state == LockState.Locked, 'not locked');
    _state = LockState.Unlocked;

    emit LockStateChanged(LockState.Unlocked);
  }
}


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
   * @param beneficiary purchaser account address
   * @param tokenAmount amount of tokens purchased
   */
  function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
    _balances[beneficiary] = _balances[beneficiary].add(tokenAmount);
  }
}


/**
 * @title SoftRefundableCrowdsale
 * @dev Provides functionality to keep funds on goal escrow and to refund them if softcap goal has not been reached.
 * If it has, it starts to send funds to separate non-refundabe escrow.
 * Also, provides methods to refund funds after crowdsale finalized buy softcap goal not reached.
 */
contract SoftRefundableCrowdsale is LockedDeliveryCrowdsale {

  using SafeMath for uint256;

  // immutable softcap goal in wei
  uint256 private _minGoal;

  // refundable goal escrow
  RefundEscrow private _goalEscrow;
  // non-refundable raise escrow
  CorporateEscrow private _raiseEscrow;

  /**
   * @param minGoal Minimal goal to be raised (softcap) in wei
   * @param salesOwner Administrative account address
   */
  constructor (uint256 minGoal, address salesOwner) public {
    require(minGoal > 0, 'requires minGoal > 0');

    _raiseEscrow = new CorporateEscrow(wallet());
    _raiseEscrow.transferOwnership(salesOwner);

    _goalEscrow = new RefundEscrow(wallet());
    _minGoal = minGoal;

    transferOwnership(salesOwner);
  }

  /**
   * @return softcap goal set in the contract
   */
  function goal() public view returns (uint256) {
    return _minGoal;
  }

  /**
   * @return true if softcap goal has been reached, false otherwise
   */
  function goalReached() public view returns (bool) {
    return weiRaised() >= _minGoal;
  }

  /**
   * @dev Returns the balance of refundable goal escrow
   * @return goal balance in wei
   */
  function goalBalance() public view returns(uint256) {
    return address(_goalEscrow).balance;
  }

  /**
   * @dev Returns the balance of non-refundable raise escrow
   * @return raise balance in wei
   */
  function raiseBalance() public view returns(uint256) {
    return address(_raiseEscrow).balance;
  }

  /**
   * @dev Returns cumulative balance of both goal and raise escrow
   * @return total balance in wei
   */
  function totalBalance() public view returns(uint256) {
    return goalBalance().add(raiseBalance());
  }

  /**
   * @dev Allows to unlock funds after reaching softcap. This means that raised funds can be withdrawn to corporate wallet;
   * also tokens can be withdrawn by purchasers to their accounts, provided by parent LockedDeliveryCrowdsale class.
   * Only owner can call this method.
   */
  function unlockFunds() public onlyOwner {
    require(goalReached(), 'goal must be reached to unlock funds');
    unlockState();

    _goalEscrow.close();
  }

  /**
   * @dev Allows to refund funds by purchaser after crowdsale has been finalized but the softcap goal has not been reached.
   * @param refundee purchaser address
   */
  function claimRefund(address payable refundee) public {
    require(finalized(), 'no refunds allowed before crowdsale is closed');
    require(!goalReached(), 'no refunds allowed after successful softcap');

    _goalEscrow.withdraw(refundee);
    releaseTokens(refundee);
  }

  /**
   * @dev Allows owner to withdraw all raised funds to corporate wallet. Only possible after softcap has been reached.
   */
  function withdraw() public onlyOwner {
    require(!isLocked(), 'crowdsale is in locked state');

    if (address(_goalEscrow).balance > 0) {
      _goalEscrow.beneficiaryWithdraw();
    }

    // allows to withdraw zero balance
    _raiseEscrow.withdraw();
  }

  /**
   * @dev Allows owner to change corporate wallet address.
   * @param beneficiar wallet address to send raised funds to
   */
  function changeBeneficiar(address payable beneficiar) public onlyOwner {
    _raiseEscrow.changeBeneficiar(beneficiar);
  }

  /**
   * @dev Finalization logic. If the softcap is not hit, enable refunds on the goal escrow.
   */
  function _finalization() internal {
    if (!goalReached()) {
      _goalEscrow.enableRefunds();
    }

    super._finalization();
  }

  /**
   * @dev Forwards funds from token purchases to either goal escrow or raise escrow, depending on whether contract state is unlocked.
   */
  function _forwardFunds() internal {
    if (isLocked()) {
      _goalEscrow.deposit.value(msg.value)(msg.sender);
    } else {
      _raiseEscrow.deposit.value(msg.value)(msg.sender);
    }
  }
}


/**
  * @title OnlsCrowdsale
  * @dev Main crowdsale contract. Base features:
  * - does not transfer tokens to the contract account, but approves respective amount to be sold
  * - implements post-delivery functionality, meaning that tokens are not transfered to purchaser account
  *   right away, but instead are put to purchaser balance inside the contract
  * - locks collected funds and sold tokens, disallowing to withdraw them while in locked state
  * - sets immutable softcap in wei, which must be reached before contract can be unlocked
  * - creates two escrow contracts to accumulate collected funds
  * - before reaching softcap, funds will be held on "goal" escrow
  * - after reaching softcap, funds will be held on "raise" escrow
  * - provides method for manual unlocking after reaching softcap; if softcap has not been reached, unlock will not be possible
  * - after unlocking, tokens can be withdrawn to purchaser account; respectively, raised funds can be withdrawn to corporate account
  * - allows to finalize crowdsale, thus closing it in a way that tokens can't be bought anymore
  * - if the softcap has not been reached, finalized crowdsale allows to refund collected funds and return sold tokens to owner account
  * - sets corporate wallet address upon deployment; this is the account where raised funds will be sent to on withdrawal
  * - allows to update corporate wallet address
  * - sets token price in wei based on exchange rate of usd to eth
  * - sets minimum and maximum purchase allowances based on exchange rate of usd to eth
  * - allows to update exchange rate of usd to eth; token wei price, minimum and maximum purchase values will be updated as per new rate
  */
contract OnlsCrowdsale is SoftRefundableCrowdsale, AllowanceCrowdsale {

  // immutable price of token in usd cents
  uint256 private _tokenPriceUsd;
  // immutable minimum purchase threshold in usd cents
  uint256 private _minPurchaseUsd;
  // immutable maximum purchase threshold in usd cents
  uint256 private _maxPurchaseUsd;

  // mutable rate of usd cent to wei
  uint256 private _usdRate;

  // mutable min-max purchase thresholds in wei; re-calculated every time when usd rate is updated
  uint256 private _minPurchaseWei;
  uint256 private _maxPurchaseWei;

  // minimal purchase guard
  modifier minimalPurchaseValue {
    require(msg.value >= _minPurchaseWei, 'minimal purchase value required');
    _;
  }

  // maximum purchase guard
  modifier maximumPurchaseValue {
    require(msg.value <= _maxPurchaseWei, 'maximum purchase value exceeded');
    _;
  }

  /**
   * @dev Emits upon successful usd rate update
   * @param rate new rate in wei per cent
   * @param minPurchase new value of minimal purchase in wei
   * @param maxPurchase new value of maximum purchase in wei
   */
  event UsdRateUpdated(uint256 rate, uint256 minPurchase, uint256 maxPurchase);

  /**
    * @param salesOwner Address of the sales administrator account
    * @param tokenOwner Address of the account to which the amount of tokens has been approved
    * @param tokenPriceUsd Fixed price of token in USD cents
    * @param usdRate Exchange rate of USD cent to WEI. Can be updated after deployment.
    * @param minPurchaseUsd Minimum amount that can be spent on tokens in USD
    * @param maxPurchaseUsd Maximum amount that can be spent on tokens in USD
    * @param minGoal Minimal goal (soft cap) in WEI. Upon reaching this goal, raised funds and sold tokens can be unlocked and withdrawn.
    * @param fundsWallet Address of EOA where raised funds will be forwarded to
    * @param token Address of the token contract
    */
  constructor(
    address salesOwner,
    address tokenOwner,
    uint256 tokenPriceUsd,
    uint256 usdRate,
    uint256 minPurchaseUsd,
    uint256 maxPurchaseUsd,
    uint256 minGoal,
    address payable fundsWallet,
    IERC20 token
  ) Crowdsale(tokenPriceUsd.mul(usdRate), fundsWallet, token)
    FinalizableCrowdsale()
    AllowanceCrowdsale(tokenOwner)
    SoftRefundableCrowdsale(minGoal, salesOwner)
    public
  {
    // immutable variables
    _usdRate = usdRate;
    _tokenPriceUsd = tokenPriceUsd;
    _minPurchaseUsd = minPurchaseUsd;
    _maxPurchaseUsd = maxPurchaseUsd;

    // mutable state variables, will be updated on usd rate change
    _minPurchaseWei = _minPurchaseUsd.mul(_usdRate);
    _maxPurchaseWei = _maxPurchaseUsd.mul(_usdRate);
  }

  /**
   * @dev Updates exchange rate of usd to eth. Rate is set in amount of wei per 1 usd cent.
   * Also updates minPurchase and maxPurchase state variables, and emits UsdRateUpdated event.
   * @param usdRate Cost in wei per usd cent
   */
  function updateUsdRate(uint256 usdRate) public onlyOwner {
    _usdRate = usdRate;
    _minPurchaseWei = _minPurchaseUsd.mul(_usdRate);
    _maxPurchaseWei = _maxPurchaseUsd.mul(_usdRate);

    emit UsdRateUpdated(_usdRate, _minPurchaseWei, _maxPurchaseWei);

    _updateRate(_tokenPriceUsd.mul(_usdRate));
  }

  /**
   * @dev Returns usd to eth rate stored in contract state
   * @return rate in wei per usd cent
   */
  function getUsdRate() public view returns(uint256) {
    return _usdRate;
  }

  /**
   * @dev Returns price needs to be paid for specific amount of tokens
   * @return tokens value in wei
   */
  function getWeiTokenPrice(uint256 amount) public view returns(uint256) {
    return rate().mul(amount);
  }

  /**
   * @dev Returns price of amount of tokens in usd cents
   * @param amount amount of tokens
   * @return price of specified amount in usd cents
   */
  function getUsdTokenPrice(uint256 amount) public view returns(uint256) {
    return _tokenPriceUsd.mul(amount);
  }

  /**
   * @dev Returns amount of tokens that can be purchased for specified amount of wei
   * @param weiAmount value in wei
   * @return amount of tokens
   */
  function getWeiTokenAmount(uint256 weiAmount) public view returns (uint256) {
    return _getTokenAmount(weiAmount);
  }

  /**
   * @dev Returns amount of tokens that can be purchased for specified amount of usd cents
   * @param usdAmount value in usd cents
   * @return amount of tokens
   */
  function getUsdTokenAmount(uint256 usdAmount) public view returns (uint256) {
    return usdAmount.div(_tokenPriceUsd);
  }

  /**
   * @dev Internal implementation of getWeiTokenAmount public method.
   * Throws an exception if wei amount passed is not a multiple of token wei price.
   * @param weiAmount value in wei
   * @return amount of tokens
   */
  function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
    require(weiAmount.mod(rate()) == 0, 'invalid wei value passed');
    uint256 amount = weiAmount.div(rate());
    return amount;
  }

  /**
   * @dev Provides modifier guards for minimum and maximum allowed purchase values
   */
  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal minimalPurchaseValue maximumPurchaseValue view {
    super._preValidatePurchase(beneficiary, weiAmount);
  }
}
