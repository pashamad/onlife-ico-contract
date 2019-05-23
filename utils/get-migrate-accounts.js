module.exports.getMigrateAccounts = function getMigrateAccounts(network, accounts, config) {

  let migrateAccount, salesOwner, fundsWallet;

  switch (network) {
    case 'development': {
      ({ migrateAccount, salesOwner, fundsWallet } = config.development.accounts);
      break;
    }
    case 'onlifedev':
    case 'onlifedev-fork':
    case 'ropsten': {
      ({ migrateAccount, salesOwner, fundsWallet } = config.ropsten.accounts);
      break;
    }
    default: {
      throw new Error(`Unknown network name ${network}`);
    }
  }

  return { migrateAccount, salesOwner, fundsWallet };
}
