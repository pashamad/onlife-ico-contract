const BN = require('bn.js');

const config = require('../config');
const { toWei, fromWei, toBN } = require('../utils/eth');

const OnlsToken = artifacts.require('./OnlsToken.sol');
const OnlsCrowdsale = artifacts.require('./OnlsCrowdsale.sol');

const seedShare = config.shared.totalSupply / 100 * config.crowdsale.sharePercent;
const usdPrice = config.crowdsale.usdPrice * 100;
const usdRate = toBN(
  toWei(String(Math.floor(config.shared.usdRate * 1000000000)), 'ether')
).div(toBN('100000000000'));

const minPurchase = config.crowdsale.minPurchase * 100;
const maxPurchase = config.crowdsale.maxPurchase * 100;
const minGoal = toBN(web3.utils.toWei(String(config.crowdsale.minGoal * config.shared.usdRate), 'ether'));
let tokenWeiPrice = usdRate.mul(toBN(usdPrice));


contract('OnlsCrowdsale', ([_, admin, fundsWallet, buyer, secondaryWallet]) => {

  let token, crowdsale, tokensSold = 0, weiSpent = new BN(0);

  before(() => {
    OnlsToken.deployed().then(inst => {
      token = inst;
      return OnlsCrowdsale.deployed();
    }).then(inst => {
      crowdsale = inst;
    });
  });

  it('initializes the seed contract with the correct values', () => {

    return OnlsCrowdsale.deployed().then(() => {
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
    return OnlsCrowdsale.deployed().then(() => {
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
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice + 1 });
    }).then(assert.fail).catch((error) => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when msg.value is not multiple of token price in wei');
      tokensToBuy = Math.ceil(minPurchase / usdPrice);
      tokensSold += tokensToBuy;
      weiSpent = weiSpent.add(tokenWeiPrice.mul(toBN(tokensToBuy)));
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

  it('forbids to withdraw funds before contract is unlocked', () => {
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.withdraw();
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts if not allowed');
    });
  });

  it('forbids to unlock contract before minimum goal has been reached', () => {
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.releaseFunds({ from: admin });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts on unlock attempt');
    });
  });

  it('returns goalReached = true after minimum goal has been reached', () => {
    let tokensToBuy;
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.goal();
    }).then((raised) => {
      return crowdsale.weiRaised();
    }).then((raised) => {
      const remainingGoal = minGoal.sub(raised);
      tokensToBuy = Math.ceil(remainingGoal.div(tokenWeiPrice).toNumber());
      const weiToSend = tokenWeiPrice.mul(toBN(tokensToBuy));
      tokensSold += tokensToBuy;
      weiSpent = weiSpent.add(weiToSend);
      return crowdsale.sendTransaction({ from: buyer, value: toWei(weiToSend) });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      return crowdsale.goalReached();
    }).then(goalReached => {
      assert.equal(goalReached, true, 'gloalReached returns true')
    });
  });


  it('allows owner to update exchange rate of usd to eth', () => {

    const newUsdRateEth = 0.0025;
    const newUsdRate = toBN(
      toWei(String(Math.floor(newUsdRateEth * 1000000000)), 'ether')
    ).div(toBN('100000000000'));

    return OnlsCrowdsale.deployed().then(() => {
      tokenWeiPrice = newUsdRate.mul(toBN(usdPrice));
      return crowdsale.updateUsdRate(toWei(newUsdRate), { from: admin });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 2, 'triggers two events');
      assert.equal(receipt.logs[0].event, 'UsdRateUpdated', 'should emit the "UsdRateUpdated" event');
      assert.equal(receipt.logs[1].event, 'TokenRateUpdated', 'should emit the "TokensPurchased" event');
    });
  });

  it('does not allow to buy tokens for less than minimal amount of funds', () => {
    OnlsCrowdsale.deployed().then(() => {
      return crowdsale.getUsdTokenAmount(minPurchase - 1);
    }).then(amount => {
      return crowdsale.getWeiTokenPrice(amount);
    }).then(price => {
      let weiToSend = +toWei(price);
      return crowdsale.sendTransaction({ from: buyer, value: weiToSend });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when value is less than minimum');
    });
  });

  it('does not allow to buy tokens for more than maximum amount of funds', () => {
    OnlsCrowdsale.deployed().then(() => {
      const maxTokens = maxPurchase / usdPrice;
      return crowdsale.getWeiTokenPrice(maxTokens + 1);
    }).then(price => {
      let weiToSend = toWei(price);
      return crowdsale.sendTransaction({ from: buyer, value: weiToSend });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when value is more than maximum');
    });
  });

  it('allows to see the balance of both goal and raise escrows', () => {
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.goalBalance();
    }).then(bal => {
      assert.equal(String(toWei(bal)), String(toWei(weiSpent)), 'returns correct goal balance');
      return crowdsale.raiseBalance();
    }).then(bal => {
      assert.equal(toWei(bal), 0, 'returns correct zero raise balance');
    });
  });

  it('forbids to withdraw tokens while tokens lock is active', () => {
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.withdrawTokens(buyer);
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts on attempt to withdraw tokens');
    });
  });

  it('allows owner to manually unlock funds withdrawal after goal has been reached', () => {
    return OnlsCrowdsale.deployed().then(() => {
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
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.goalBalance();
    }).then(bal => {
      goalBalance = bal;
      return crowdsale.getUsdTokenAmount(minPurchase);
    }).then(amount => {
      let tokensToBuy = amount.toNumber() + 1
      const weiToSend = tokenWeiPrice.mul(toBN(tokensToBuy));
      tokensSold += tokensToBuy;
      valueSpent = weiToSend;
      weiSpent = weiSpent.add(weiToSend);
      return crowdsale.sendTransaction({ from: buyer, value: toWei(weiToSend) });
    }).then(receipt => {
      return crowdsale.raiseBalance();
    }).then(bal => {
      assert.equal(String(toWei(bal)), String(toWei(valueSpent)), 'raise balance should be equal to value spent');
      return crowdsale.goalBalance();
    }).then(bal => {
      assert.equal(String(toWei(bal)), String(toWei(goalBalance)), 'goal balance should not increase');
    });
  });

  it('shows correct values of wei raised and total balance', () => {
    let weiRaised, totalBalance;
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.weiRaised();
    }).then(raised => {
      weiRaised = raised;
      return crowdsale.totalBalance();
    }).then(bal => {
      totalBalance = bal;
      assert.equal(String(toWei(totalBalance)), String(toWei(weiSpent)), 'total balance corresponds to wei spent');
      assert.equal(String(toWei(weiRaised)), String(toWei(weiSpent)), 'wei raised corresponst to wei spent');
    });
  });

  it('allows owner to withdraw funds to corporate wallet', () => {
    let lastBalance, weiRaised;
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.weiRaised();
    }).then(raised => {
      weiRaised = raised;
      return web3.eth.getBalance(fundsWallet);
    }).then(bal => {
      lastBalance = toBN(bal);
      return crowdsale.withdraw({ from: admin });
    }).then(receipt => {
      // @todo: check receipt event log
      return web3.eth.getBalance(fundsWallet);
    }).then(bal => {
      let currBalance = toBN(bal);
      let delta = currBalance.sub(lastBalance);
      assert.equal(String(toWei(delta)), String(toWei(weiRaised)), 'adds wei raised to corporate wallet account');
      return crowdsale.totalBalance();
    }).then(bal => {
      assert.equal(String(toWei(bal)), '0', 'reduces total balance to 0');
    });
  });

  it('allows owner to change corporate wallet address', () => {
    let lastBalance, weiSpentSecondary;
    return OnlsCrowdsale.deployed().then(() => {
      return web3.eth.getBalance(secondaryWallet);
    }).then(bal => {
      lastBalance = toBN(bal);
      return crowdsale.changeBeneficiar(0x0, { from: admin });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts on invalid address')
      return crowdsale.changeBeneficiar(fundsWallet, { from: admin });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts on same beneficiar')
      return crowdsale.changeBeneficiar(secondaryWallet, { from: admin });
    }).then(receipt => {
      // @todo: check receipt event log
      const tokensToBuy = Math.ceil(toBN(minPurchase).mul(usdRate).div(tokenWeiPrice).toNumber());
      const weiToSend = tokenWeiPrice.mul(toBN(tokensToBuy));
      tokensSold += tokensToBuy;
      weiSpentSecondary = weiToSend;
      return crowdsale.sendTransaction({ value: toWei(weiToSend), from: buyer });
    }).then(receipt => {
      return crowdsale.withdraw({ from: admin });
    }).then(receipt => {
      return web3.eth.getBalance(secondaryWallet);
    }).then(bal => {
      let delta = toBN(bal).sub(lastBalance);
      assert.equal(String(toWei(delta)), String(toWei(weiSpentSecondary)), 'adds wei spent to secondary corporate wallet account');
    });
  });

  it('allows forced refunds by sales owner');

  // TODO: time dependent test, passes with a test flag that disables timestamp check
  // it('allows to withdraw tokens after the sale has been closed', () => {
  //   return OnlsCrowdsale.deployed().then(() => {
  //     return crowdsale.withdrawTokens(buyer);
  //   }).then(receipt => {
  //     // @todo: check receipt event log
  //     return crowdsale.balanceOf(buyer);
  //   }).then(amount => {
  //     assert.equal(amount.toNumber(), 0, 'reduces buyer amount on sale contract to 0')
  //     return token.balanceOf(buyer);
  //   }).then(amount => {
  //     assert.equal(amount.toNumber(), tokensSold, 'adds correct amount to token balance of buyer');
  //   });
  // });

  // TODO: time dependent test
  it('allows refunds if the sale is closed and goal is not reached');

  // TODO: time dependent test
  // it('controls sale opening and closing times', () => {
  //   return OnlsCrowdsale.deployed().then(() => {
  //     return increaseTime(config.crowdsale.closingDuration + SECONDS_IN_A_DAY);
  //   }).then((r) => {
  //     return crowdsale.sendTransaction({ from: buyer, value: tokenWeiPrice });
  //   }).then(assert.fail).catch(error => {
  //     assert(error.message.indexOf('revert') >= 0, 'reverts when trying to buy tokens after sale has been closed');
  //   });
  // });

});
