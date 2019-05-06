const OnlsToken = artifacts.require('./OnlsToken.sol');
const OnlsSeedSale = artifacts.require('./OnlsSeedSale.sol');

const TOTAL_SUPPLY = 1000000000;
const SEED_SHARE = TOTAL_SUPPLY / 100 * 2.25;
const SEED_PRICE = 0.75;
const USD_RATE = 0.0063;
const TOKEN_WEI_PRICE = USD_RATE * SEED_PRICE * 1e18;

contract('OnlsSeedSale', (accounts) => {

  const ADMIN = accounts[1];
  const FUNDS_WALLET = accounts[2];
  const BUYER = accounts[3];
  let tokenInstance;
  let seedInstance;

  it('initializes the seed contract with the correct values', () => {
    return OnlsSeedSale.deployed().then(instance => {
      seedInstance = instance;
      return seedInstance.address;
    }).then(address => {
      assert.notEqual(address, 0x0, 'has contract address');
      return OnlsToken.deployed();
    }).then(instance => {
      tokenInstance = instance;
      return seedInstance.token();
    }).then(tokenAddress => {
      assert.equal(tokenAddress, tokenInstance.address, 'sets sales token to onls token');
      return seedInstance.wallet();
    }).then(walletAddress => {
      assert.equal(walletAddress, FUNDS_WALLET, 'sets target wallet to correct address');
      return seedInstance.rate()
    }).then(rate => {
      assert.equal(rate.toNumber(), TOKEN_WEI_PRICE, 'sets correct token rate in wei');
    });
  });

  it('initializes correct amount of tokens for sale', () => {
    return OnlsSeedSale.deployed().then(() => {
      return tokenInstance.balanceOf(seedInstance.address);
    }).then(seedBalance => {
      assert.equal(seedBalance.toNumber(), 0, 'does not send any tokens to the contract');
      return tokenInstance.balanceOf(ADMIN);
    }).then(adminBalance => {
      assert.equal(adminBalance.toNumber(), TOTAL_SUPPLY, 'keeps all the tokens on admin account');
      return tokenInstance.allowance(ADMIN, seedInstance.address);
    }).then(seedAllowance => {
      assert.equal(seedAllowance.toNumber(), SEED_SHARE, 'sets correct allowance for seed contract');
      return seedInstance.remainingTokens();
    }).then(remainingTokens => {
      assert.equal(remainingTokens.toNumber(), SEED_SHARE, 'shows correct value of remaining tokens');
    });
  });

  it('allows to buy tokens', () => {
    return OnlsSeedSale.deployed().then(() => {
      return seedInstance.sendTransaction({ from: BUYER, value: TOKEN_WEI_PRICE + 100000 });
    }).then(assert.fail).catch((error) => {
      assert(error.message.indexOf('revert') >= 0, 'msg.value must be multiple of token price in wei');
      return seedInstance.sendTransaction({ from: BUYER, value: TOKEN_WEI_PRICE });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      assert.equal(receipt.logs[0].args.purchaser, BUYER, 'logs the account of purchaser');
      assert.equal(receipt.logs[0].args.beneficiary, BUYER, 'logs the account of beneficiary');
      assert.equal(receipt.logs[0].args.value.toNumber(), TOKEN_WEI_PRICE, 'logs the amount spent in wei');
      assert.equal(receipt.logs[0].args.amount.toNumber(), 1, 'logs the amount of purchased tokens');
    });
  });
});
