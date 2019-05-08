const { increaseTime } = require("../utils/increase-time");
const { increaseBlock } = require("../utils/increase-block");

const config = require('../config');
const { toWei, fromWei } = require('../utils/eth');

const OnlsToken = artifacts.require('./OnlsToken.sol');
const OnlsSeedSale = artifacts.require('./OnlsSeedSale.sol');

const SECONDS_IN_A_DAY = 86400;

const seedShare = config.shared.totalSupply / 100 * config.seed.sharePercent;
const usdPrice = String(config.seed.usdPrice * 100);
const usdEth = String(config.shared.usdEth * 1e16);
const tokenWeiPrice = web3.utils.toWei(`${config.shared.usdEth * config.seed.usdPrice}`, 'ether');
const minGoal = `${web3.utils.toWei(`${config.seed.minGoal * config.shared.usdEth}`)}`;
const minBuy = `${web3.utils.toWei(`${config.seed.minBuy * config.shared.usdEth}`)}`;
const unlockTime = config.seed.openingTime + config.seed.unlockDuration;
const closingTime = config.seed.openingTime + config.seed.closingDuration;

contract('OnlsSeedSale', ([_, admin, fundsWallet, buyer, fisher]) => {

  let token, crowdsale, tokensSold = 0, weiSpent = 0;

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
      assert.equal(addr, fundsWallet, 'sets funds wallet to correct address');
      return crowdsale.rate();
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
      assert.equal(bal.toNumber(), config.shared.totalSupply, 'keeps all the tokens to token owner account');
      return token.allowance(admin, crowdsale.address);
    }).then(allowance => {
      assert.equal(allowance.toNumber(), seedShare, 'sets correct allowance for seed contract');
      return crowdsale.remainingTokens();
    }).then(remaining => {
      assert.equal(remaining.toNumber(), seedShare, 'shows correct value of remaining tokens');
    });
  });

  it('allows to buy tokens and keeps them on the contract owner wallet', () => {
    let tokensToBuy;
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice + 1 });
    }).then(assert.fail).catch((error) => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when msg.value is not multiple of token price in wei');
      tokensToBuy = Math.ceil(minBuy / tokenWeiPrice);
      tokensSold += tokensToBuy;
      weiSpent += tokenWeiPrice * tokensToBuy;
      return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice * tokensToBuy });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      assert.equal(receipt.logs[0].args.purchaser, buyer, 'logs the account of purchaser');
      assert.equal(receipt.logs[0].args.beneficiary, buyer, 'logs the account of beneficiary');
      assert.equal(toWei(receipt.logs[0].args.value), tokenWeiPrice * tokensToBuy, 'logs the amount spent in wei');
      assert.equal(receipt.logs[0].args.amount.toNumber(), tokensToBuy, 'logs the amount of purchased tokens');
      return crowdsale.balanceOf(buyer);
    }).then(bal => {
      assert.equal(bal.toNumber(), tokensSold, 'adds correct amount of tokens to buyer balance on the crowdsale contract');
      return crowdsale.weiRaised();
    }).then(wei => {
      assert.equal(toWei(wei), tokenWeiPrice * tokensSold, 'adds buy value to raised amount of wei');
      return crowdsale.remainingTokens();
    }).then(remaining => {
      assert.equal(toWei(remaining), seedShare, 'does not deduct tokens from token owner account');
    });
  });

  it('forbids to withdraw funds before minimum goal is reached', () => {
    let tokensToBuy;
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.withdraw();
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts if not allowed');
      return crowdsale.weiRaised();
    }).then((raised) => {
      const remainingGoal = minGoal - toWei(raised);
      tokensToBuy = Math.ceil(remainingGoal / tokenWeiPrice);
      const weiToSend = tokensToBuy * tokenWeiPrice;
      tokensSold += tokensToBuy;
      weiSpent += tokenWeiPrice * tokensToBuy;
      return crowdsale.sendTransaction({ from: buyer, value: weiToSend });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      assert.equal(receipt.logs[0].args.purchaser, buyer, 'logs the account of purchaser');
      assert.equal(receipt.logs[0].args.beneficiary, buyer, 'logs the account of beneficiary');
      assert.equal(fromWei(receipt.logs[0].args.value, 'ether'), fromWei(`${tokenWeiPrice * tokensToBuy}`, 'ether'), 'logs the amount spent in wei');
      assert.equal(receipt.logs[0].args.amount.toNumber(), tokensToBuy, 'logs the amount of purchased tokens');
      return crowdsale.balanceOf(buyer);
    }).then(bal => {
      assert.equal(bal.toNumber(), tokensSold, 'adds tokens to purchaser balance on sales contract');
    });
  });

  it('allows owner to update exchange rate of usd to eth');

  it('does not allow to buy tokens for less than minimal amount of funds', () => {
    OnlsSeedSale.deployed().then(() => {
      return crowdsale.getUsdTokenAmount(config.seed.minBuy * 100 - 1);
    }).then(amount => {
      return crowdsale.getWeiTokenPrice(amount);
    }).then(weiValue => {
      let value = toWei(weiValue);
      return crowdsale.sendTransaction({ from: buyer, value: value });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when value is less than minimum');
    });
  });

  it('does not allow to buy tokens for more than maximum amount of funds (possibly redundant)');

  it('allows to see the balance of both goal and raise escrows', () => {
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.goalBalance();
    }).then(bal => {
      assert.equal(toWei(bal), tokensSold * tokenWeiPrice, 'returns correct goal balance');
      return crowdsale.raiseBalance();
    }).then(bal => {
      assert.equal(toWei(bal), 0, 'returns correct zero raise balance');
    });
  });

  it('allows owner to manually unlock funds withdrawal after goal has been reached', () => {
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.goal();
    }).then(goal => {
      return crowdsale.weiRaised();
    }).then(raised => {
      // @todo test error from non-owner account
      return crowdsale.releaseFunds({ from: admin });
    }).then((receipt) => {
      // @todo: check receipt event log
      assert.equal(true, true, 'releases funds without error');
    });
  });

  it('sends funds to the raise escrow after goal has been reached', () => {
    let valueSpent, goalBalance;
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.goalBalance();
    }).then(bal => {
      goalBalance = toWei(bal);
      return crowdsale.getUsdTokenAmount(config.seed.minBuy * 100);
    }).then(amount => {
      let tokensToBuy = amount.toNumber() + 1
      let value = toWei(`${tokensToBuy * tokenWeiPrice}`);
      tokensSold += tokensToBuy;
      valueSpent = value;
      return crowdsale.sendTransaction({ from: buyer, value: value });
    }).then(receipt => {
      return crowdsale.raiseBalance();
    }).then(bal => {
      assert.equal(toWei(bal), valueSpent, 'raise balance should be equal to value spent');
      return crowdsale.goalBalance();
    }).then(bal => {
      assert.equal(`${toWei(bal)}`, `${goalBalance}`, 'goal balance should not increase');
    });
  });

  it('shows correct values of wei raised and total balance');

  it('allows owner to withdraw funds to corporate wallet', () => {
    let lastBalance, weiRaised, totalBalance = 0;
    return OnlsSeedSale.deployed().then(() => {
      return crowdsale.weiRaised();
    }).then(raised => {
      weiRaised = toWei(raised);
      return web3.eth.getBalance(fundsWallet);
    }).then(bal => {
      lastBalance = bal;
      return crowdsale.goalBalance();
    }).then(bal => {
      totalBalance += +toWei(bal);
      return crowdsale.raiseBalance();
    }).then(bal => {
      totalBalance += +toWei(bal);
      return crowdsale.withdraw({ from: admin });
    }).then(receipt => {
      // @todo check logs event
      return web3.eth.getBalance(fundsWallet);
    }).then(bal => {
      let delta = toWei(bal) - lastBalance;
      // console.log(`delta bal: ${delta}`);
      // console.log(`delta rai: ${weiRaised}`);
      // console.log(`delta spe: ${weiSpent}`);
      // assert.equal(delta, totalBalance, 'adds wei raised to corporate wallet account');
    });
  });

  it('allows owner to change corporate wallet address');

  it('forbids to withdraw tokens while tokens lock is active');

  it('allows to withdraw tokens after the sale has been closed');

  // time dependant test
  it('allows refunds if the sale is closed and goal is not reached');

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
