(function() {
  module.exports = function(samjs) {
    var Crypto, bcrypt, crypto;
    bcrypt = samjs.Promise.promisifyAll(require("bcryptjs"));
    crypto = samjs.Promise.promisifyAll(require("crypto"));
    return new (Crypto = (function() {
      function Crypto() {}

      Crypto.prototype.generateHashedPassword = function(user, next) {
        return bcrypt.genSaltAsync(samjs.options.saltWorkFactor).then(function(salt) {
          return bcrypt.hashAsync(user[samjs.options.password], salt);
        }).then(function(hash) {
          user[samjs.options.password] = hash;
          return next();
        });
      };

      Crypto.prototype.comparePassword = function(providedPassword, realPassword) {
        return new samjs.Promise(function(resolve, reject) {
          return bcrypt.compareAsync(providedPassword, realPassword).then(function(isMatch) {
            if (isMatch) {
              return resolve();
            } else {
              return reject();
            }
          });
        });
      };

      Crypto.prototype.generateToken = function(size) {
        return crypto.randomBytesAsync(size).call("toString", "base64");
      };

      return Crypto;

    })());
  };

}).call(this);
