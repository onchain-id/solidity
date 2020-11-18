const fs = require('fs');

function replaceAddressOnImplementation(address) {

  fs.readFile("./contracts/Proxy/UpgradableProxy.sol", 'utf8', function (err,data) {
    if (err) {
      return console.log(err);
    }
    console.log(data);
    var result = data.replace(/0x0000000000000000000000000000000000000000/g, address);
    console.log(result);

    fs.writeFile("./build/UpgradableProxyWithImplementation.sol", result, 'utf8', function (err) {
      if (err) return console.log(err);
    });
  });
}


module.exports = {
  replaceAddressOnImplementation,
};
