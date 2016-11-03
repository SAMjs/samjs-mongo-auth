(function() {
  module.exports = function(samjs) {
    var MongoAuth, debug, getProps, hasForbiddenKey, hasForbiddenProp, processAuth;
    debug = samjs.debug("mongo-auth");
    if (!samjs.mongo) {
      throw new Error("samjs-mongo not found - must be loaded before samjs-mongo-auth");
    }
    if (!samjs.auth) {
      throw new Error("samjs-auth not found - must be loaded before samjs-mongo-auth");
    }
    getProps = function(user) {
      var i, id, key, len, mode, obj, perm, ref, ref1, val;
      id = samjs.auth.callPermissionChecker(user, null, Object.assign({
        getIdentifier: true
      }, this.authOptions));
      obj = this._props[id];
      if (obj == null) {
        obj = {
          read: {
            allowed: [],
            forbidden: []
          },
          write: {
            allowed: [],
            forbidden: []
          }
        };
        ref = ["read", "write"];
        for (i = 0, len = ref.length; i < len; i++) {
          mode = ref[i];
          ref1 = this.schema.paths;
          for (key in ref1) {
            val = ref1[key];
            if (val.options[mode] != null) {
              perm = val.options[mode];
            } else {
              perm = this.access[mode];
            }
            if (samjs.auth.getAllowance(user, perm, this.authOptions) === "") {
              obj[mode].allowed.push(key);
            } else {
              obj[mode].forbidden.push(key);
            }
          }
          if (obj[mode].allowed.length > 0) {
            obj[mode].allowed.push("_id");
          } else {
            obj[mode].forbidden.push("_id");
          }
        }
        this._props[id] = obj;
      }
      return obj;
    };
    processAuth = function(obj, mode) {
      var props, ref, ref1, user;
      if (((ref = obj.socket) != null ? (ref1 = ref.client) != null ? ref1.auth : void 0 : void 0) == null) {
        throw new Error("invalid socket - no auth");
      }
      user = obj.socket.client.auth.user;
      if (mode === "read") {
        props = this.getProps(user)[mode];
        if (props.allowed.length > 0) {
          return props;
        }
      } else if (samjs.auth.getAllowance(user, this.access[mode], this.authOptions) === "") {
        if (["insert", "update", "delete"].indexOf(mode) > -1) {
          mode = "write";
        }
        return this.getProps(user)[mode];
      }
      throw new Error("no permission");
    };
    hasForbiddenKey = function(obj, forbidden) {
      var key, results, util, val;
      if (forbidden.length > 0) {
        util = samjs.util;
        results = [];
        for (key in obj) {
          val = obj[key];
          if (util.isString(val)) {
            if (forbidden.indexOf(key) > -1) {
              throw new Error("no permission");
            } else {
              results.push(void 0);
            }
          } else if (util.isArray(val)) {
            results.push((function() {
              var i, len, results1;
              results1 = [];
              for (i = 0, len = val.length; i < len; i++) {
                obj = val[i];
                results1.push(hasForbiddenKey(obj, forbidden));
              }
              return results1;
            })());
          } else if (util.isObject(val)) {
            results.push(hasForbiddenKey(val, forbidden));
          } else {
            results.push(void 0);
          }
        }
        return results;
      }
    };
    hasForbiddenProp = function(str, forbidden) {
      var i, len, prop, ref, results;
      if (forbidden.length > 0) {
        ref = str.split(" ");
        results = [];
        for (i = 0, len = ref.length; i < len; i++) {
          prop = ref[i];
          if (forbidden.indexOf(prop) > -1) {
            throw new Error("no permission");
          } else {
            results.push(void 0);
          }
        }
        return results;
      }
    };
    samjs.mongo.plugins({
      auth: function(options) {
        if (options == null) {
          options = {};
        }
        this._props = {};
        this.getProps = getProps.bind(this);
        this.processAuth = processAuth.bind(this);
        this.addHook("beforeFind", function(obj) {
          var allowed, forbidden, ref;
          ref = this.processAuth(obj, "read"), allowed = ref.allowed, forbidden = ref.forbidden;
          hasForbiddenKey(obj.query.find, forbidden);
          if (obj.query.fields != null) {
            hasForbiddenProp(obj.query.fields, forbidden);
          } else if (forbidden.length > 0) {
            obj.query.fields = allowed.join(" ");
          }
          return obj;
        });
        this.addHook("beforeInsert", function(obj) {
          var forbidden;
          forbidden = this.processAuth(obj, "insert").forbidden;
          hasForbiddenKey(obj.query, forbidden);
          return obj;
        });
        this.addHook("afterInsert", function(obj) {
          var allowed, i, len, result, str;
          allowed = this.processAuth(obj, "read").allowed;
          result = {};
          for (i = 0, len = allowed.length; i < len; i++) {
            str = allowed[i];
            result[str] = obj.result[str];
          }
          obj.result = result;
          return obj;
        });
        this.addHook("beforeUpdate", function(obj) {
          var forbiddenRead, forbiddenWrite;
          forbiddenWrite = this.processAuth(obj, "update").forbidden;
          forbiddenRead = this.processAuth(obj, "read").forbidden;
          hasForbiddenKey(obj.query.cond, forbiddenRead);
          hasForbiddenKey(obj.query.doc, forbiddenWrite);
          return obj;
        });
        this.addHook("beforeDelete", function(obj) {
          var forbidden;
          forbidden = this.processAuth(obj, "delete").forbidden;
          hasForbiddenKey(obj.query, forbidden);
          return obj;
        });
        return this.addHook("beforePopulate", function(obj) {
          var allowed, forbidden, i, len, populate, ref, ref1;
          ref = obj.populate;
          for (i = 0, len = ref.length; i < len; i++) {
            populate = ref[i];
            if (populate.samjsmodel.processAuth != null) {
              ref1 = populate.samjsmodel.processAuth(obj, "read"), forbidden = ref1.forbidden, allowed = ref1.allowed;
              if (populate.match != null) {
                hasForbiddenKey(populate.match, forbidden);
              }
              if (populate.select != null) {
                hasForbiddenProp(populate.select, forbidden);
              } else if (forbidden.length > 0) {
                populate.select = allowed.join(" ");
              }
            } else {
              throw new Error("populating failed");
            }
          }
          return obj;
        });
      }
    });
    return new (MongoAuth = (function() {
      function MongoAuth() {}

      MongoAuth.prototype.name = "mongoAuth";

      MongoAuth.prototype.hasForbiddenKey = hasForbiddenKey;

      MongoAuth.prototype.hasForbiddenProp = hasForbiddenProp;

      return MongoAuth;

    })());
  };

}).call(this);
