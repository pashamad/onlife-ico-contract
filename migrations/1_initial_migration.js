const Migrations = artifacts.require("Migrations");

const { getMigrateAccounts } = require('../utils/get-migrate-accounts');

const config = require('../config');

module.exports = function (deployer, network, accounts) {

  ({ migrateAccount } = getMigrateAccounts(network, accounts, config.migrate));

  deployer.deploy(Migrations, { from: migrateAccount });
};
