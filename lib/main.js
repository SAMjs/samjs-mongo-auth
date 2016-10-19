(function() {
  module.exports = function(samjs) {
    var MongoAuth, debug, getTree, processQuery;
    debug = samjs.debug("mongo-auth");
    if (!samjs.mongo) {
      throw new Error("samjs-mongo not found - must be loaded before samjs-mongo-auth");
    }
    if (!samjs.auth) {
      throw new Error("samjs-auth not found - must be loaded before samjs-mongo-auth");
    }
    getTree = function(schema) {
      if (schema.tree) {
        return schema.tree;
      } else {
        return schema;
      }
    };
    processQuery = function(obj, mode, permissionChecker, all) {
      var count, k, props, ref, user, v;
      if (this[mode] != null) {
        return samjs.auth.isAllowed(obj.client, this[mode], permissionChecker);
      } else {
        if (obj.client.auth == null) {
          throw new Error("invalid socket - no auth");
        }
        if (all == null) {
          throw new Error("no permission");
        }
        user = obj.client.auth.user;
        props = [];
        count = 0;
        ref = getTree(this.schema);
        for (k in ref) {
          v = ref[k];
          if (k === "_id" || k === "id" || k === "__v") {
            continue;
          }
          count++;
          if (samjs.auth.getAllowance(user, v[mode], permissionChecker) === "") {
            props.push(k);
          } else {
            if (all === true || (all[k] != null)) {
              throw new Error("no permission");
            }
          }
        }
        if (count === props.length) {
          return true;
        } else {
          props.push("_id");
        }
        return props;
      }
    };
    samjs.mongo.plugins({
      auth: function(options) {
        if (options == null) {
          options = {};
        }
        if (options.insertable == null) {
          options.insertable = true;
        }
        if (options.deletable == null) {
          options.deletable = false;
        }
        this.addHook("beforeFind", (function(_this) {
          return function(obj) {
            var fields, i, len, prop, props, ref;
            props = processQuery.bind(_this)(obj, "read", _this.permissionChecker, obj.query.find);
            if (props !== true) {
              if ((obj.query.fields != null) && obj.query.fields !== "") {
                fields = [];
                ref = obj.query.fields.split(" ");
                for (i = 0, len = ref.length; i < len; i++) {
                  prop = ref[i];
                  if (props.indexOf(prop) > -1) {
                    fields.push(prop);
                  }
                }
              } else {
                fields = props;
              }
              obj.query.fields = props.join(" ");
            }
            return obj;
          };
        })(this));
        this.addHook("beforeInsert", (function(_this) {
          return function(obj) {
            var all;
            if (options.insertable) {
              all = obj.query;
            } else {
              all = true;
            }
            processQuery.bind(_this)(obj, "write", _this.permissionChecker, all);
            return obj;
          };
        })(this));
        this.addHook("beforeUpdate", (function(_this) {
          return function(obj) {
            var k, key, newDoc, props, ref, ref1, v, val;
            props = processQuery.bind(_this)(obj, "read", _this.permissionChecker, obj.query.cond);
            if (props !== true) {
              ref = obj.query.cond;
              for (key in ref) {
                val = ref[key];
                if (props.indexOf(key) === -(1 != null)) {
                  throw new Error("not allowed");
                }
              }
            }
            props = processQuery.bind(_this)(obj, "write", _this.permissionChecker, obj.query.doc);
            if (props !== true) {
              newDoc = {};
              ref1 = obj.query.doc;
              for (k in ref1) {
                v = ref1[k];
                if (props.indexOf(k) > -1) {
                  newDoc[k] = v;
                }
              }
              obj.query.doc = newDoc;
            }
            return obj;
          };
        })(this));
        this.addHook("beforeDelete", (function(_this) {
          return function(obj) {
            var all;
            if (options.deletable) {
              all = obj.query;
            } else {
              all = true;
            }
            processQuery.bind(_this)(obj, "write", _this.permissionChecker, true);
            return obj;
          };
        })(this));
        return this.addHook("afterCreate", function() {
          var k, results, tree, v;
          if (samjs.authMongo != null) {
            tree = getTree(this.schema);
            results = [];
            for (k in tree) {
              v = tree[k];
              if (v != null) {
                if (v.read) {
                  v._read = samjs.authMongo.parsePermission(v.read);
                }
                if (v.write) {
                  results.push(v._write = samjs.authMongo.parsePermission(v.write));
                } else {
                  results.push(void 0);
                }
              } else {
                results.push(void 0);
              }
            }
            return results;
          }
        });
      }
    });
    return new (MongoAuth = (function() {
      function MongoAuth() {}

      MongoAuth.prototype.name = "mongoAuth";

      MongoAuth.prototype.getTree = getTree;

      return MongoAuth;

    })());
  };

}).call(this);
