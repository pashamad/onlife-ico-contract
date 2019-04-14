const token = artifacts.require("../contracts/ONLSTestToken.sol");
const crowdsale = artifacts.require("../contracts/ONLSTestCrowdsale.sol");

module.exports = function (deployer, network, accounts) {
  const openingTime = Math.round(new Date().getTime() / 1000) + 120;
  const closingTime = 1560456300;
  const rate = 1;
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
    });
};
