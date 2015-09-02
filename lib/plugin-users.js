(function() {
  module.exports = function(samjs, common) {
    var authInterface;
    authInterface = require("./interface")(samjs, common);
    return function(options) {
      var base, properties;
      if (options == null) {
        options = {};
      }
      if (options.read == null) {
        options.read = samjs.options.groupRoot;
      }
      if (options.write == null) {
        options.write = samjs.options.groupRoot;
      }
      options.read = common.parsePermission(options.read);
      options.write = common.parsePermission(options.write);
      properties = {};
      properties[samjs.options.username] = {
        type: String,
        required: true,
        index: {
          unique: true
        },
        read: options.read,
        write: options.write
      };
      properties[samjs.options.password] = {
        type: String,
        required: true,
        write: options.write
      };
      properties[samjs.options.group] = {
        type: String,
        required: true,
        read: options.read,
        write: options.write
      };
      properties[samjs.options.loginDate] = {
        type: Date,
        read: options.read,
        write: options.write
      };
      this.schema.add(properties);
      this.schema.pre("save", function(next) {
        return common.crypto.generateHashedPassword(this, next);
      });
      this.schema.methods.comparePassword = function(providedPassword) {
        return common.crypto.comparePassword(providedPassword, this[samjs.options.password]).then((function(_this) {
          return function() {
            return _this;
          };
        })(this));
      };
      if ((base = this.interfaces).auth == null) {
        base.auth = [];
      }
      this.interfaces.auth.push(authInterface);
      this.test = function(value) {
        return new samjs.Promise((function(_this) {
          return function(resolve, reject) {
            return _this.dbModel.count({
              group: samjs.options.groupRoot
            }, function(err, data) {
              if (err != null) {
                return reject(err);
              }
              if (data === 0) {
                return reject("no " + samjs.options.groupRoot + " found");
              }
              return resolve();
            });
          };
        })(this));
      };
      this.installInterface = function(socket) {
        socket.on("root.set", (function(_this) {
          return function(request) {
            var created;
            if (((request != null ? request.content : void 0) != null) && (request.token != null) && (request.content[samjs.options.username] != null) && (request.content[samjs.options.password] != null)) {
              request.content.group = samjs.options.groupRoot;
              created = new Promise(function(resolve, reject) {
                return _this.dbModel.create(request.content, function(err) {
                  if (err != null) {
                    return reject(err);
                  }
                  return resolve();
                });
              }).then(function() {
                return {
                  success: true,
                  content: false
                };
              })["catch"](function(e) {
                return {
                  success: false,
                  content: e != null ? e.message : void 0
                };
              }).then(function(response) {
                socket.emit("root.set." + request.token, response);
                if (response.success) {
                  common.debug("user installed completely");
                  return samjs.emit("checkInstalled");
                }
              });
              return created;
            } else {
              return socket.emit("root.set." + request.token, {
                success: false,
                content: "Username and password required"
              });
            }
          };
        })(this));
        return function() {
          if (socket != null) {
            return socket.removeAllListeners("root.set");
          }
        };
      };
      this.findUser = function(userName) {
        var find;
        find = {};
        find[samjs.options.username] = userName;
        return new samjs.Promise((function(_this) {
          return function(resolve, reject) {
            return _this.dbModel.findOne(find).exec().then(resolve, reject);
          };
        })(this));
      };
      this.setLoginDate = function(userName) {
        var find, update;
        find = {};
        find[samjs.options.username] = userName;
        update = {};
        update[samjs.options.loginDate] = Date.now();
        return new samjs.Promise((function(_this) {
          return function(resolve, reject) {
            return _this.dbModel.update(find, update, function(err) {
              if (err != null) {
                return reject(err);
              }
              return resolve();
            });
          };
        })(this));
      };
      return this;
    };
  };

}).call(this);
