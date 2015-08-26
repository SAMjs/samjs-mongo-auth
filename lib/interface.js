(function() {
  module.exports = function(samjs, common) {
    var tokenStore;
    tokenStore = {};
    return function(socket) {
      socket.on("disconnect", function() {
        var ref, ref1, timoutObj, token;
        if (((ref = socket.client) != null ? (ref1 = ref.auth) != null ? ref1.token : void 0 : void 0) != null) {
          token = socket.client.auth.token;
          if (tokenStore[token]) {
            timoutObj = setTimeout((function() {
              return delete tokenStore[token];
            }), samjs.options.tokenExpiration);
            if (tokenStore[token].removeTimeout) {
              tokenStore[token].removeTimeout();
            }
            return tokenStore[token].removeTimeout = function() {
              return clearTimeout(timoutObj);
            };
          }
        }
      });
      socket.on("auth.byToken", (function(_this) {
        return function(request) {
          var content, storedItem, success, token, user;
          success = false;
          content = false;
          if ((request != null) && (request.token != null) && (request.content != null)) {
            token = request.content;
            storedItem = tokenStore[token];
            if (storedItem) {
              if (storedItem.removeTimeout) {
                storedItem.removeTimeout();
              }
              storedItem.resetLongTimeout();
              user = storedItem.user;
              content = {};
              content[samjs.options.username] = user[samjs.options.username];
              content[samjs.options.group] = user[samjs.options.group];
              success = true;
              _this.setLoginDate(user);
              socket.client.auth.user = user;
              socket.client.auth.token = token;
            }
            return socket.emit("auth.byToken." + request.token, {
              success: success,
              content: content
            });
          }
        };
      })(this));
      return socket.on("auth", (function(_this) {
        return function(request) {
          if ((request != null) && (request.content != null) && (request.content[samjs.options.username] != null) && (request.content[samjs.options.password] != null) && (request.token != null)) {
            return _this.findUser(request.content[samjs.options.username]).call("comparePassword", request.content[samjs.options.password]).then(function(user) {
              return common.crypto.generateToken(samjs.options.tokenSize).then(function(token) {
                var content, success;
                success = true;
                content = {
                  token: token
                };
                content[samjs.options.username] = user[samjs.options.username];
                content[samjs.options.group] = user[samjs.options.group];
                tokenStore[token] = {
                  user: user
                };
                tokenStore[token].resetLongTimeout = function() {
                  var timoutObj;
                  if (timoutObj) {
                    clearTimeout(timoutObj);
                  }
                  return timoutObj = setTimeout((function() {
                    return delete tokenStore[token];
                  }), samjs.options.tokenExpiration * 50);
                };
                tokenStore[token].resetLongTimeout();
                _this.setLoginDate(user[samjs.options.username]);
                socket.client.auth.user = user;
                socket.client.auth.token = token;
                return content;
              });
            }).then(function(content) {
              return {
                success: true,
                content: content
              };
            })["catch"](function(e) {
              return {
                success: false,
                content: false
              };
            }).then(function(response) {
              return socket.emit("auth." + request.token, response);
            });
          } else {
            return socket.emit("root.set." + request.token, {
              success: false,
              content: false
            });
          }
        };
      })(this));
    };
  };

}).call(this);
