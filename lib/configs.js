(function() {
  module.exports = function(samjs, common) {
    var isAllowed;
    isAllowed = function(client, mode) {
      var base, base1, group, ref;
      if (!this[mode]) {
        throw new Error("no permission");
      }
      if ((client != null ? (ref = client.auth) != null ? ref.getGroup : void 0 : void 0) == null) {
        throw new Error("invalid socket - no auth");
      }
      group = client.auth.getGroup();
      if (this.allowedFields == null) {
        this.allowedFields = {};
      }
      if ((base = this.allowedFields)[group] == null) {
        base[group] = {};
      }
      if ((base1 = this.allowedFields[group])[mode] == null) {
        base1[mode] = this[mode].indexOf(group) > -1;
      }
      if (!this.allowedFields[group][mode]) {
        throw new Error("no permission");
      }
    };
    return {
      mutator: function(options) {
        if (options == null) {
          options = {};
        }
        if (options.read != null) {
          if (options.read === true) {
            options.read = samjs.options.groupRoot;
          }
          options.read = common.parsePermission(options.read);
        }
        if (options.write != null) {
          if (options.write === true) {
            options.write = samjs.options.groupRoot;
          }
          options.write = common.parsePermission(options.write);
        }
        return options;
      },
      test: function(data, client) {
        isAllowed.bind(this)(client, "write");
        return data;
      },
      get: function(client) {
        return isAllowed.bind(this)(client, "read");
      },
      set: function(data, client) {
        isAllowed.bind(this)(client, "write");
        return data;
      }
    };
  };

}).call(this);
