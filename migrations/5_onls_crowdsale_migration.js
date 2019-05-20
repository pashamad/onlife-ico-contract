const OnlsToken = artifacts.require("../contracts/OnlsToken");
const OnlsCrowdsale = artifacts.require("../contracts/OnlsCrowdsale");

// const { toWei, fromWei, toBN } = require('../utils/eth');
// const BN = require('bn.js');
// const web3 = require('web3.js');

const config = require('../config');

const seedShare = String(config.shared.totalSupply / 100 * config.crowdsale.sharePercent);
const usdPrice = String(config.crowdsale.usdPrice * 100);
// const usdRate = web3.utils.toWei(String(config.shared.usdRate / 100), 'ether');
// const ux1000 = Math.floor(config.shared.usdRate * 1000000000);
// console.log(`ux100: ${ux1000}`);
// const uxBn = web3.utils.toBN(String(ux1000));
// console.log(`uxBn: ${uxBn.toNumber()}`);
// const uxW = web3.utils.toWei(uxBn, 'ether');
// console.log(`uxW: ${uxW}`);
// const ud1000 = web3.utils.toBN('100000000000');
// const urcW = web3.utils.toBN(uxW).div(ud1000);
// console.log(`urcW: ${urcW.toNumber()}`);

// console.log(`ud1000: ${ud1000.toNumber()}`);
// const urBn = uxBn.div(ud1000);
// console.log(`urBn: ${urBn.toNumber()}`);
const usdRate = web3.utils.toBN(
  web3.utils.toWei(String(Math.floor(config.shared.usdRate * 1000000000)), 'ether')
).div(web3.utils.toBN('100000000000'));
// console.log(`usdRate: ${usdRate.toNumber()}`);

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
