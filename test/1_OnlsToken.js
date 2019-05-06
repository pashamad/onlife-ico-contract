const OnlsToken = artifacts.require('./OnlsToken.sol');

const TOTAL_SUPPLY = 1000000000;

contract('OnlsToken', (accounts) => {

  const ADMIN = accounts[1];
  let tokenInstance;

  it('initialize token with the correct values', () => {
    return OnlsToken.deployed().then(instance => {
      tokenInstance = instance;
      return tokenInstance.address;
    }).then(address => {
      assert.notEqual(address, 0x0, 'has contract address');
      return tokenInstance.totalSupply();
    }).then(totalSupply => {
      assert.equal(totalSupply.toNumber(), TOTAL_SUPPLY, 'has correct total supply');
      return tokenInstance.balanceOf(ADMIN);
    });
  });

  it('mints initial supply of tokens to admin account', () => {
    return OnlsToken.deployed().then((instance) => {
      tokenInstance = instance;
      return tokenInstance.balanceOf(ADMIN);
    }).then(adminBalance => {
      assert.equal(adminBalance.toNumber(), TOTAL_SUPPLY, 'admin account has all the tokens');
    });
  });
});
