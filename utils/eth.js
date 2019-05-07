module.exports.toWei = function toWei(n, u = 'wei') {
  return web3.utils.toWei(n, u);
}

module.exports.fromWei = function fromWei(bn, u = 'ether') {
  return web3.utils.fromWei(bn, u);
}
