const OnlsToken = artifacts.require("../contracts/OnlsToken");
const OnlsCrowdsale = artifacts.require("../contracts/OnlsCrowdsale");

const { calculateUsdRate } = require('../utils/usd-rate');

const config = require('../config');

// amount of tokens provided for crowdsale
const seedShare = config.shared.totalSupply / 100 * config.crowdsale.sharePercent;
// price of token in USD cents
const usdPrice = config.crowdsale.usdPrice * 100;
// BigNumber of WEI cost of 1 USD cent
const usdRate = calculateUsdRate(config.shared.usdRate, web3.utils);
// minimal allowed purchase in USD cents
const minPurchase = config.crowdsale.minPurchase * 100;
// maximal allowed purchase in USD cents
const maxPurchase = config.crowdsale.maxPurchase * 100;
// BigNumber of WEI required to raise to be able to unlock sales contract (softcap)
const minGoal = usdRate.mul(web3.utils.toBN(config.crowdsale.minGoal * 100));

module.exports = function (deployer, network, accounts) {

  const migrateConfig = config.migrate.ropsten;
  let admin, fundsWallet;

  switch (network) {
    case 'development': {
      [
        admin,
        fundsWallet
      ] = accounts.slice(1);
      break;
    }
    case 'ropsten': {
      admin = migrateConfig.accounts.admin;
      fundsWallet = migrateConfig.accounts.fundsWallet;
      break;
    }
    default: {
      throw new Error(`Invalid network name ${network}`);
    }
  }

  let tokenInstance;
  let seedInstance;

  deployer.deploy(OnlsToken, admin).then(instance => {
    tokenInstance = instance;
    return tokenInstance.address;
  }).then(tokenAddress => {
    return deployer.deploy(
      OnlsCrowdsale,
      admin, // sales owner account
      admin, // token owner account
      usdPrice, // price in USD cents per token
      usdRate, // usd to eth rate in WEI
      minPurchase, // minimum purchase in USD cents
      maxPurchase, // maximum purchase in USD cents
      minGoal, // min goal in WEI to unlock funds withdrawal (softcap)
      fundsWallet, // wallet to send raised funds to
      tokenAddress // address of the token contract
    );
  }).then(instance => {
    seedInstance = instance;
    return tokenInstance.approve(seedInstance.address, seedShare, { from: admin });
  });
};
