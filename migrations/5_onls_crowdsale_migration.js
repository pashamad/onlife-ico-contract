const OnlsToken = artifacts.require("../contracts/OnlsToken");
const OnlsSeedSale = artifacts.require("../contracts/OnlsSeedSale");

const config = require('../config');

// const TOTAL_SUPPLY = 1000000000;
// const SEED_SHARE = TOTAL_SUPPLY / 100 * 2.25;
// const SEED_PRICE = 0.75;
// const USD_RATE = 0.0063;
// const GOAL = 200000;
// const OPENING = Math.round(new Date().getTime() / 1000);
// const CLOSING = OPENING + 24 * 3600 * 365;

const seedShare = config.shared.totalSupply / 100 * config.seed.sharePercent;
const usdPrice = String(config.seed.usdPrice * 100);
// const tokenWeiPrice = config.shared.usdEth * config.seed.usdPrice * 1e18;
const usdEth = String(config.shared.usdEth * 1e16);
const minGoal = String(config.seed.minGoal * config.shared.usdEth) + '0'.repeat(18);
const closingTime = config.seed.openingTime + config.seed.closingDuration;

module.exports = function (deployer, network, accounts) {

  // const ADMIN = accounts[1];
  // const FUNDS_WALLET = accounts[2];

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
    // const seedPrice = String(SEED_PRICE * 100);
    // const usdRate = String(USD_RATE * 1e16);
    // const goal = String(GOAL * USD_RATE) + '0'.repeat(18);
    return deployer.deploy(OnlsSeedSale, admin, usdPrice, usdEth, minGoal, config.seed.openingTime, closingTime, fundsWallet, tokenAddress);
  }).then(instance => {
    seedInstance = instance;
    return tokenInstance.approve(seedInstance.address, seedShare, { from: admin });
  });
};
