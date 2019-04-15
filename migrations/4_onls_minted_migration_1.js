const token = artifacts.require("../contracts/ONLSMintableToken.sol");
const crowdsale = artifacts.require("../contracts/ONLSMintedCrowdsale.sol")

module.exports = function (deployer, network, accounts) {

  const openingTime = Math.round(new Date().getTime() / 1000) + 60;
  const closingTime = openingTime + 60 * 24 * 30;
  const rate = 1;
  const cap = web3.utils.toWei('200');
  const goal = web3.utils.toWei('100');

  let wallet;
  if (network === 'development') {
    wallet = accounts[0];
  } else {
    wallet = '0x52250807be77a54672e935a60156babda83a3839';
  }

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
      token.deployed().then(instance => {
        instance.addMinter(crowdsale.address);
      })
    });
};
