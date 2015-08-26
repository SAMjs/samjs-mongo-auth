(function() {
  module.exports = function(samjs, common) {
    return function() {
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
      return this;
    };
  };

}).call(this);
