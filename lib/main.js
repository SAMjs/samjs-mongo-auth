(function() {
  module.exports = function(samjs) {
    var common;
    common = require("./common")(samjs);
    samjs.mongo.plugins({
      auth: require("./plugin-auth")(samjs, common),
      users: require("./plugin-users")(samjs, common)
    });
    return {
      name: "auth",
      options: require("./options"),
      configs: require("./configs")(samjs, common),
      models: [
        {
          name: "users",
          schema: {},
          db: "mongo",
          plugins: {
            "users": null,
            "auth": null
          },
          isRequired: true,
          isExisting: function() {
            var model, name, ref;
            ref = samjs.models;
            for (name in ref) {
              model = ref[name];
              if (model.plugins.users != null) {
                return true;
              }
            }
            return false;
          }
        }
      ],
      startup: function() {
        common.debug("adding auth property to clients");
        return samjs.io.use(function(socket, next) {
          socket.client.auth = {
            getGroup: function() {
              var group;
              if (socket.client.auth.user && socket.client.auth.user.group) {
                return group = socket.client.auth.user.group;
              } else {
                return group = samjs.options.groupDefault;
              }
            }
          };
          return next();
        });
      }
    };
  };

}).call(this);
