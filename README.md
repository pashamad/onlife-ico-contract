## Description

Repository for developing and testing ITO smart-contracts.

#### OnlsCrowdsale contract

Main crowdsale contract. Base features:
  - does not transfer tokens to the contract account, but approves respective amount to be sold
  - implements post-delivery functionality, meaning that tokens are not transfered to purchaser account right away, but instead are put to purchaser balance inside the contract
  - locks collected funds and sold tokens, disallowing to withdraw them while in locked state
  - sets immutable softcap in wei, which must be reached before contract can be unlocked
  - creates two escrow contracts to accumulate collected funds
  - before reaching softcap, funds will be held on "goal" escrow
  - after reaching softcap, funds will be held on "raise" escrow
  - provides method for manual unlocking after reaching softcap; if softcap has not been reached, unlock will not be possible
  - after unlocking, tokens can be withdrawn to purchaser account; respectively, raised funds can be withdrawn to corporate account
  - allows to finalize crowdsale, thus closing it in a way that tokens can't be bought anymore
  - if the softcap has not been reached, finalized crowdsale allows to refund collected funds and return sold tokens to owner account
  - sets corporate wallet address upon deployment; this is the account where raised funds will be sent to on withdrawal
  - allows to update corporate wallet address
  - sets token price in wei based on exchange rate of usd to eth
  - sets minimum and maximum purchase allowances based on exchange rate of usd to eth
  - allows to update exchange rate of usd to eth; token wei price, minimum and maximum purchase values will be updated as per new rate

## Requirements

  * node-js@^10.4
  * npm@^6.9

## Installation

```
npm i
```

## Compile and deploy

#### Compile

```
npm run compile
```

#### Test deployment

Run Ganache and then execute

```
npm run deploy
```

This will compile and deploy contracts to a private development network.

#### Production deployment

*Not implemented*

## Testing

#### Autotests

Deploy contracts to a development network as described before and then execute

```
npm test
```
