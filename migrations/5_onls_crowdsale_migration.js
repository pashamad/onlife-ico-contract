const OnlsToken = artifacts.require("../contracts/OnlsToken");
const OnlsCrowdsale = artifacts.require("../contracts/OnlsCrowdsale");

const config = require('../config');

const seedShare = String(config.shared.totalSupply / 100 * config.crowdsale.sharePercent);
const usdPrice = String(config.crowdsale.usdPrice * 100);
const usdRate = web3.utils.toWei(String(config.shared.usdRate / 100), 'ether');

const minPurchase = String(config.crowdsale.minPurchase * 100);
const maxPurchase = String(config.crowdsale.maxPurchase * 100);
const minGoal = web3.utils.toBN(web3.utils.toWei(String(config.crowdsale.minGoal * config.shared.usdRate), 'ether'));

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
      OnlsCrowdsale,
      admin, // sales owner account
      admin, // token owner account
      usdPrice, // price in USD cents per token
      usdRate, // usd to eth rate in WEI
      minPurchase, // minimum purchase in USD cents
      maxPurchase, // maximum purchase in USD cents
      minGoal, // min goal in WEI to release funds withdrawal (softcap)
      fundsWallet, // wallet to send raised funds to
      tokenAddress // address of the token contract
    );
  }).then(instance => {
    seedInstance = instance;
    return tokenInstance.approve(seedInstance.address, seedShare, { from: admin });
  });
};
