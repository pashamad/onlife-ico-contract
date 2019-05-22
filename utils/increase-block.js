module.exports.increaseBlock = function increaseBlock(increment) {

  const id = Date.now();

  return new Promise((resolve, reject) => {

    for (let i = 0, p = Promise.resolve(); i < increment; i++) {
      p = p.then(_ => new Promise((resolve, reject) => {
        web3.currentProvider.send(
          {
            jsonrpc: "2.0",
            method: "evm_mine",
            id: id + 1
          },
          (err, res) => {
            return err ? reject(err) : resolve(res);
          }
        );
      }));
    }

  });
};
