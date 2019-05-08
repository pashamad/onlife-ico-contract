const OnlsToken = artifacts.require("../contracts/OnlsToken");
const OnlsSeedSale = artifacts.require("../contracts/OnlsSeedSale");

const config = require('../config');

const seedShare = config.shared.totalSupply / 100 * config.seed.sharePercent;
const usdPrice = String(config.seed.usdPrice * 100);
const usdEth = String(config.shared.usdEth * 1e16);
const minGoal = `${web3.utils.toWei(`${config.seed.minGoal * config.shared.usdEth}`)}`;
const minBuy = `${web3.utils.toWei(`${config.seed.minBuy * config.shared.usdEth}`)}`;
const unlockTime = config.seed.openingTime + config.seed.unlockDuration;
const closingTime = config.seed.openingTime + config.seed.closingDuration;

module.exports = function (deployer, network, accounts) {

  const [
    admin,
    fundsWallet
  ] = accounts.slice(1);

  let tokenInstance;
  let seedInstance;

  deployer.deploy(OnlsToken, admin).then(instance => {
    tokenInstance = instance;
    return tokenInstance.address;
  }).then(tokenAddress => {
    return deployer.deploy(
      OnlsSeedSale,
      admin, // sales owner account
      admin, // token owner account
      usdPrice, // price in cents per token
      usdEth, // usd to eth rate
      minGoal, // min goal in wei to release funds withdrawal
      minBuy, // min amount of wei that can be spend on tokens
      config.seed.openingTime, // opening time of sales
      unlockTime, // time when the tokens will be released
      closingTime, // time when the sales will be closed
      fundsWallet, // wallet to send raised funds to
      tokenAddress // address of the token contract
    );
  }).then(instance => {
    seedInstance = instance;
    return tokenInstance.approve(seedInstance.address, seedShare, { from: admin });
  });
};
