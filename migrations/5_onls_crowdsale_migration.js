const OnlsToken = artifacts.require("../contracts/OnlsToken");
const OnlsSeedSale = artifacts.require("../contracts/OnlsSeedSale");

const TOTAL_SUPPLY = 1000000000;
const SEED_SHARE = TOTAL_SUPPLY / 100 * 2.25;
const SEED_PRICE = 0.75;
const USD_RATE = 0.0063;
const GOAL = 200000;
const OPENING = Math.round(new Date().getTime() / 1000) + 1;
const CLOSING = OPENING + 24 * 3600 * 365;

module.exports = function (deployer, network, accounts) {

  const ADMIN = accounts[1];
  const FUNDS_WALLET = accounts[2];

  let tokenInstance;
  let seedInstance;

  deployer.deploy(OnlsToken, ADMIN).then(instance => {
    tokenInstance = instance;
    return tokenInstance.address;
  }).then(tokenAddress => {
    const seedPrice = String(SEED_PRICE * 100);
    const usdRate = String(USD_RATE * 1e16);
    const goal = String(GOAL * USD_RATE) + '0'.repeat(18);
    return deployer.deploy(OnlsSeedSale, ADMIN, seedPrice, usdRate, goal, OPENING, CLOSING, FUNDS_WALLET, tokenAddress);
  }).then(instance => {
    seedInstance = instance;
    return tokenInstance.approve(seedInstance.address, SEED_SHARE, { from: ADMIN });
  });
};
