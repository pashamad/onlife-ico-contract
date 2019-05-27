const decimals = 8;

/**
 * @dev Converts rate of ETHUSDT with up to 8 decimals to a cost of 1 cent in WEI
 * @param {Number} r rate of eth to usd with 8 decimals precicion
 * @param {Object} utils web3 utils object
 * @return {BigNumber} cost of wei per 1 cent
 */
module.exports.calculateUsdRate = function toWei(r, utils) {

  const factor = 10 ** decimals;
  const baseRate = utils.toBN(Math.floor(r * factor));
  const eth = utils.toBN(utils.toWei('1', 'ether'));
  const perCent = utils.toBN(100);
  const usdRate = eth.div(baseRate).mul(utils.toBN(factor)).div(perCent);

  return usdRate;
}
