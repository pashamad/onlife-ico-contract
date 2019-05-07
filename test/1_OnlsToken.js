const OnlsToken = artifacts.require('./OnlsToken.sol');

const config = require('../config');

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
      assert.equal(decimals, config.shared.tokenDecimals);
      return tokenInstance.totalSupply();
    }).then(totalSupply => {
      assert.equal(totalSupply.toNumber(), config.shared.totalSupply, 'has correct total supply');
      return tokenInstance.balanceOf(admin);
    });
  });

  it('mints initial supply of tokens to admin account', () => {
    return OnlsToken.deployed().then((instance) => {
      tokenInstance = instance;
      return tokenInstance.balanceOf(admin);
    }).then(adminBalance => {
      assert.equal(adminBalance.toNumber(), config.shared.totalSupply, 'admin account has all the tokens');
    });
  });
});
