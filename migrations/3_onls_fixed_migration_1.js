const token = artifacts.require("../contracts/TokenERC20.sol");
const crowdsale = artifacts.require("../contracts/Crowdsale.sol")

module.exports = function (deployer, network, accounts) {

  let wallet;
  if (network === 'development') {
    wallet = accounts[0];
  } else {
    wallet = '0x52250807be77a54672e935a60156babda83a3839';
  }

  return deployer
    .then(() => {
      return deployer.deploy(token, 250, 'OnLife Test Token', 'ONLST');
    })
    .then(() => {
      return deployer.deploy(crowdsale, wallet, 100, 60 * 24 * 30, 1, token.address);
    });
};
