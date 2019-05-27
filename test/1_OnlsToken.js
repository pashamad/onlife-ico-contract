const OnlsToken = artifacts.require('./OnlsToken.sol');

const { toWei, toBN } = require('../utils/eth');

const config = require('../config');

const grandTotal = toBN(config.shared.totalSupply).mul(toBN(10 ** config.shared.tokenDecimals));

contract('OnlsToken', (accounts) => {

  const admin = accounts[1];
  let tokenInstance;

  it('initialize token with the correct values', () => {
    return OnlsToken.deployed().then(instance => {
      tokenInstance = instance;
      return tokenInstance.address;
    }).then(address => {
      assert.notEqual(address, 0x0, 'has contract address');
      return tokenInstance.name();
    }).then((name) => {
      assert.equal(name, config.shared.tokenName);
      return tokenInstance.symbol();
    }).then((symbol) => {
      assert.equal(symbol, config.shared.tokenSymbol);
      return tokenInstance.decimals();
    }).then((decimals) => {
      assert.equal(decimals.toNumber(), config.shared.tokenDecimals);
      return tokenInstance.totalSupply();
    }).then(totalSupply => {
      assert.equal(totalSupply.toString(), grandTotal.toString(), 'has correct total supply');
      return tokenInstance.balanceOf(admin);
    });
  });

  it('mints initial supply of tokens to admin account', () => {
    return OnlsToken.deployed().then((instance) => {
      tokenInstance = instance;
      return tokenInstance.balanceOf(admin);
    }).then(adminBalance => {
      assert.equal(adminBalance.toString(), grandTotal.toString(), 'admin account has all the tokens');
    });
  });
});
