(function() {
  module.exports = function(samjs) {
    var Common;
    return new (Common = (function() {
      function Common() {
        this.debug = samjs.mongo.debug("auth");
        this.crypto = require("./crypto")(samjs);
      }

      Common.prototype.getTree = function(schema) {
        if (schema.tree) {
          return schema.tree;
        } else {
          return schema;
        }
      };

      Common.prototype.parsePermission = function(permission) {
        var i;
        if (!samjs.util.isArray(permission)) {
          if (samjs.options.hierarchical) {
            i = samjs.options.groups.indexOf(permission);
            permission = samjs.options.groups.slice(i);
          } else {
            permission = [permission];
          }
        }
        return permission;
      };

      return Common;

    })());
  };

}).call(this);
