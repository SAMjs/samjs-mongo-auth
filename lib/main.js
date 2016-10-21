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
      var count, k, perm, props, ref, ref1, ref2, user, v;
      if (((ref = obj.socket) != null ? (ref1 = ref.client) != null ? ref1.auth : void 0 : void 0) == null) {
        throw new Error("invalid socket - no auth");
      }
      if (all == null) {
        throw new Error("no permission");
      }
      user = obj.socket.client.auth.user;
      props = [];
      count = 0;
      ref2 = getTree(this.schema);
      for (k in ref2) {
        v = ref2[k];
        if (k === "_id" || k === "id" || k === "__v") {
          continue;
        }
        count++;
        perm = v[mode];
        if (perm == null) {
          perm = this[mode];
        }
        if (samjs.auth.getAllowance(user, perm, permissionChecker) === "") {
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
