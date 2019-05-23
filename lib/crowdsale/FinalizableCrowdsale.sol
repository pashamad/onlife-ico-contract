pragma solidity ^0.5.0;

import "./Crowdsale.sol";
import "../ownership/Ownable.sol";

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
