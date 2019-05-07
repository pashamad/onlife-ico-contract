const { increaseTime } = require("../utils/increase-time");
const config = require('../config');

const OnlsToken = artifacts.require('./OnlsToken.sol');
const OnlsSeedSale = artifacts.require('./OnlsSeedSale.sol');

const SECONDS_IN_A_DAY = 86400;

const seedShare = config.shared.totalSupply / 100 * config.seed.sharePercent;
const usdPrice = config.seed.usdPrice * 100;
const tokenWeiPrice = config.shared.usdEth * config.seed.usdPrice * 1e18;
const usdEth = String(config.shared.usdEth * 1e16);
const minGoal = String(config.seed.minGoal * config.shared.usdEth) + '0'.repeat(18);
const closingTime = config.seed.openingTime + config.seed.closingDuration;

contract('OnlsSeedSale', accounts => {

  const [
    admin,
    funds,
    buyer
  ] = accounts.slice(1);

  let crowdsale, token;

  before(() => {

    OnlsToken.deployed().then(inst => {
      token = inst;
      return OnlsSeedSale.deployed();
    }).then(inst => {
      crowdsale = inst;
    });
  });

  it('initializes the seed contract with the correct values', () => {

    return OnlsSeedSale.deployed().then(() => {
      assert.notEqual(crowdsale.address, 0x0, 'has contract address');
      return crowdsale.token();
    }).then(addr => {
      assert.equal(addr, token.address, 'sets sales token to onls token');
      return crowdsale.wallet();
    }).then(addr => {
      assert.equal(addr, funds, 'sets funds wallet to correct address');
      return crowdsale.rate()
    }).then(rate => {
      assert.equal(rate.toNumber(), tokenWeiPrice, 'sets correct token rate in wei');
      return crowdsale.goal();
    }).then(goal => {
      assert.equal(web3.utils.fromWei(goal, 'wei'), minGoal, 'sets correct goal value');
    });
  });

  it('initializes correct amount of tokens for sale', () => {
    return OnlsSeedSale.deployed().then(() => {
      return token.balanceOf(crowdsale.address);
    }).then(bal => {
      assert.equal(bal.toNumber(), 0, 'does not send any tokens to the contract');
      return token.balanceOf(admin);
    }).then(bal => {
      assert.equal(bal.toNumber(), config.shared.totalSupply, 'keeps all the tokens to admin account');
      return token.allowance(admin, crowdsale.address);
    }).then(allowance => {
      assert.equal(allowance.toNumber(), seedShare, 'sets correct allowance for seed contract');
      return crowdsale.remainingTokens();
    }).then(remaining => {
      assert.equal(remaining.toNumber(), seedShare, 'shows correct value of remaining tokens');
    });
  });

  it('allows to buy tokens', () => {
    let fundsBefore;
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice + 100000 });
    }).then(assert.fail).catch((error) => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when msg.value is not multiple of token price in wei');
      return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      assert.equal(receipt.logs[0].args.purchaser, buyer, 'logs the account of purchaser');
      assert.equal(receipt.logs[0].args.beneficiary, buyer, 'logs the account of beneficiary');
      assert.equal(receipt.logs[0].args.value.toNumber(), tokenWeiPrice, 'logs the amount spent in wei');
      assert.equal(receipt.logs[0].args.amount.toNumber(), 1, 'logs the amount of purchased tokens');
      return crowdsale.balanceOf(buyer);
    }).then(bal => {
      assert.equal(bal.toNumber(), 1, 'transfers correct amount of tokens to buyer balance on the crowdsale contract');
      return crowdsale.weiRaised();
    }).then(wei => {
      assert.equal(wei.toNumber(), tokenWeiPrice, 'adds buy value to raised amount of wei');
    });
  });

  it('forbids to withdraw funds before minimum goal is reached', () => {
  });

  // TODO: this test requires to reload ganache because of illegal block timestamp in chain
  // it('controls sale opening and closing times', () => {
  //   return OnlsSeedSale.deployed().then(() => {
  //     return increaseTime(config.seed.closingDuration + SECONDS_IN_A_DAY);
  //   }).then((r) => {
  //     return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice });
  //   }).then(assert.fail).catch(error => {
  //     assert(error.message.indexOf('revert') >= 0, 'reverts when trying to buy tokens after sale has been closed');
  //   });
  // });

});
