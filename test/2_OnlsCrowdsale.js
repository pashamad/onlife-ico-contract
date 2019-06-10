const BN = require('bn.js');

const config = require('../config');
const { toWei, toBN } = require('../utils/eth');
const { calculateUsdRate } = require('../utils/usd-rate');

const OnlsToken = artifacts.require('./OnlsToken.sol');
const OnlsCrowdsale = artifacts.require('./OnlsCrowdsale.sol');

// amount of tokens provided for crowdsale
const seedShare = config.shared.totalSupply / 100 * config.crowdsale.sharePercent;
// price of token in USD cents
const usdPrice = config.crowdsale.usdPrice * 100;
// BigNumber of WEI cost of 1 USD cent
const usdRate = calculateUsdRate(config.shared.usdRate, web3.utils);
// minimal allowed purchase in USD cents
const minPurchase = config.crowdsale.minPurchase * 100;
// maximal allowed purchase in USD cents
const maxPurchase = config.crowdsale.maxPurchase * 100;
// BigNumber of WEI required to raise to be able to unlock sales contract (softcap)
const minGoal = usdRate.mul(web3.utils.toBN(config.crowdsale.minGoal * 100));
// price of token in WEI (mutable for testing purposes)
let tokenWeiPrice = usdRate.mul(toBN(usdPrice)).div(toBN(10 ** config.shared.tokenDecimals));
// total supply in the smallest indivisible units (considering decimals)
const grandTotal = toBN(config.shared.totalSupply).mul(toBN(10 ** config.shared.tokenDecimals));


// miscellaneous
// random ETHUSDT rate to test that updating usd rate in contract works correctly
const newUsdRate = calculateUsdRate(350.00, web3.utils);

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
      assert.equal(rate.toString(), tokenWeiPrice.toString(), 'sets correct token rate in wei');
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
      assert.equal(bal.toString(), grandTotal.toString(), 'keeps all the tokens to token owner account');
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
    let minPurchaseWei;
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.getMinPurchaseWei();
    }).then(_minPurchaseWei => {
      minPurchaseWei = _minPurchaseWei;
      return crowdsale.getWeiTokenAmount(minPurchaseWei);
    }).then(_tokensToBuy => {
      tokensToBuy = _tokensToBuy.toNumber();
      tokensSold += tokensToBuy;
      weiSpent = weiSpent.add(minPurchaseWei);
      return crowdsale.sendTransaction({ from: buyer, value: minPurchaseWei });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      assert.equal(receipt.logs[0].args.purchaser, buyer, 'logs the account of purchaser');
      assert.equal(receipt.logs[0].args.beneficiary, buyer, 'logs the account of beneficiary');
      assert.equal(toWei(receipt.logs[0].args.value.toString()), minPurchaseWei.toString(), 'logs the amount spent in wei');
      assert.equal(receipt.logs[0].args.amount.toNumber(), tokensToBuy, 'logs the amount of purchased tokens');
      return crowdsale.balanceOf(buyer);
    }).then(bal => {
      assert.equal(bal.toNumber(), tokensSold, 'adds correct amount of tokens to buyer balance on the crowdsale contract');
      return crowdsale.weiRaised();
    }).then(wei => {
      assert.equal(wei.toString(), minPurchaseWei.toString(), 'adds buy value to raised amount of wei');
      return crowdsale.remainingTokens();
    }).then(remaining => {
      assert.equal(remaining.toString(), seedShare.toString(), 'does not deduct tokens from token owner account');
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
      return crowdsale.unlockFunds({ from: admin });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts on unlock attempt');
    });
  });

  it('returns goalReached = true after minimum goal has been reached', () => {
    let remainingGoal;
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.weiRaised();
    }).then((raised) => {
      remainingGoal = minGoal.sub(raised);
      return crowdsale.getWeiTokenAmount(remainingGoal);
    }).then((tokensToBuy) => {
      tokensSold += tokensToBuy;
      weiSpent = weiSpent.add(remainingGoal);
      return crowdsale.sendTransaction({ from: buyer, value: remainingGoal });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      return crowdsale.goalReached();
    }).then(goalReached => {
      assert.equal(goalReached, true, 'gloalReached returns true')
    });
  });

  it('allows owner to update exchange rate of usd to eth', () => {
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.updateUsdRate(newUsdRate, { from: admin });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 2, 'triggers two events');
      assert.equal(receipt.logs[0].event, 'TokenRateUpdated', 'should emit the "TokenRateUpdated" event');
      assert.equal(receipt.logs[1].event, 'UsdRateUpdated', 'should emit the "UsdRateUpdated" event');
      return crowdsale.getUsdRate();
    }).then(rate => {
      assert.equal(String(toWei(rate)), String(toWei(newUsdRate)), 'returns correct usd rate after update');
      return crowdsale.rate();
    }).then(rate => {
      assert.equal(rate.toString(), newUsdRate.mul(toBN(usdPrice)).div(toBN(10 ** config.shared.tokenDecimals)).toString(),
        'returns correct token wei cost after update');
      // changing rate back to original so that to keep further tests consistent
      return crowdsale.updateUsdRate(usdRate, { from: admin });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 2, 'successfully updates rate back to original');
      return crowdsale.getUsdRate();
    }).then(rate => {
      assert.equal(rate.toString(), usdRate.toString(), 'returns correct rate after update');
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

  it('does not allow to buy tokens for more than maximum amount of funds before contract unlock', () => {
    let currBal, currBalWei;
    OnlsCrowdsale.deployed().then(() => {
      return crowdsale.balanceOf(buyer);
    }).then(bal => {
      currBal = bal;
      return crowdsale.getWeiTokenPrice(currBal);
    }).then(wei => {
      currBalWei = wei;
      return crowdsale.getMaxPurchaseWei();
    }).then(max => {
      let weiToSend = max.sub(currBalWei).add(toBN(1));
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
      assert.notEmpty(error.message, 'must be an error object with a message');
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
      return crowdsale.unlockFunds({ from: admin });
    }).then((receipt) => {
      // @todo: check receipt event log
      assert.equal(true, true, 'unlocks funds without error');
    });
  });

  it('sends funds to the raise escrow after goal has been reached', () => {
    let valueSpent, goalBalance;
    return OnlsCrowdsale.deployed().then(() => {
      return crowdsale.goalBalance();
    }).then(bal => {
      goalBalance = bal;
      return crowdsale.getMinPurchaseWei();
    }).then(_minPurchase => {
      valueSpent = _minPurchase;
      return crowdsale.sendTransaction({ from: buyer, value: _minPurchase });
    }).then(receipt => {
      assert.equal(receipt.logs.length, 1, 'triggers one event');
      assert.equal(receipt.logs[0].event, 'TokensPurchased', 'should be the "TokensPurchased" event');
      tokensSold += receipt.logs[0].args.amount.toNumber();
      weiSpent = weiSpent.add(valueSpent);
      return crowdsale.raiseBalance();
    }).then(bal => {
      assert.equal(bal.toString(), valueSpent.toString(), 'raise balance should be equal to value spent');
      return crowdsale.goalBalance();
    }).then(bal => {
      assert.equal(bal.toString(), goalBalance, 'goal balance should not increase');
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

  it('sends tokens directly to buyer wallet after contract unlock');

  it('does not allow to buy tokens for more than maximum amount of funds when tokens are both on deposit and a buyer wallet', () => {
    let currBal, currBalWei;
    OnlsCrowdsale.deployed().then(() => {
      return crowdsale.balanceOf(buyer);
    }).then(bal => {
      currBal = bal;
      return crowdsale.getWeiTokenPrice(currBal);
    }).then(wei => {
      currBalWei = wei;
      return crowdsale.getMaxPurchaseWei();
    }).then(max => {
      let weiToSend = max.sub(currBalWei).add(toBN(1));
      return crowdsale.sendTransaction({ from: buyer, value: weiToSend });
    }).then(assert.fail).catch(error => {
      assert(error.message.indexOf('revert') >= 0, 'reverts when value is more than maximum');
    });
  });

  it('allows buyer to withdraw tokens to personal wallet');

  it('allows forced refunds by sales owner');
  it('allows refunds if the sale is closed and goal is not reached');
});
