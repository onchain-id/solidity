const fs = require('fs');

function replaceAddressOnImplementation(address) {

  fs.readFile("./contracts/proxy/UpgradableProxy.sol", 'utf8', function (err,data) {
    if (err) {
      return console.log(err);
    }
    const result = data.replace(/0x0000000000000000000000000000000000000000/g, address);

    fs.writeFile("./build/UpgradableProxyWithImplementation.sol", result, 'utf8', function (err) {
      if (err) return console.log(err);
    });
  });
}

module.exports = {
  replaceAddressOnImplementation,
};
