const token = artifacts.require("../contracts/ONLSTestToken.sol");
const crowdsale = artifacts.require("../contracts/ONLSTestCrowdsale.sol");

module.exports = function (deployer, network, accounts) {
  const openingTime = TimedCrowdsale; // 2019-04-13 18:30:00
  const closingTime = 1556139600; // 2019-04-25 00:00:00
  const rate = new web3.BigNumber(1);
  const wallet = '0x52250807be77a54672e935a60156babda83a3839';
  const cap = 20 * 1000000;
  const goal = 10 * 1000000;

  return deployer
    .then(() => {
      return deployer.deploy(token);
    })
    .then(() => {
      return deployer.deploy(
        crowdsale,
        openingTime,
        closingTime,
        rate,
        wallet,
        cap,
        token.address,
        goal
      );
    })
    .then(() => {
      var tokenContract = web3.eth.contract(token.abi).at(token.address);
      web3.eth.defaultAccount = web3.eth.accounts[0];
      tokenContract.transferOwnership(crowdsale.address);
    });
};
