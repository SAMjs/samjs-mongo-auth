(function() {
  module.exports = function(samjs, common) {
    var authInterface, parsePermissionInSchema;
    parsePermissionInSchema = function(schema) {
      var k, tree, v;
      tree = common.getTree(schema);
      for (k in tree) {
        v = tree[k];
        if (v != null) {
          if (v.read) {
            v.read = common.parsePermission(v.read);
          }
          if (v.write) {
            v.write = common.parsePermission(v.write);
          }
        }
      }
      return schema;
    };
    authInterface = require("./interface")(samjs, common);
    return function(options) {
      var processWrite, properties;
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
      this.schema = parsePermissionInSchema(this.schema);
      this.interfaces.auth = authInterface;
      this.getAllowedFields = function(socket, mode) {
        var base, group, k, tree, v;
        group = socket.client.auth.getGroup();
        if (this.allowedFields == null) {
          this.allowedFields = {};
        }
        if ((base = this.allowedFields)[group] == null) {
          base[group] = {};
        }
        if (this.allowedFields[group][mode] == null) {
          tree = common.getTree(this.schema);
          this.allowedFields[group][mode] = [];
          for (k in tree) {
            v = tree[k];
            if ((v[mode] != null) && v[mode].indexOf(group) > -1) {
              this.allowedFields[group][mode].push(k);
            }
          }
          if (this.allowedFields[group][mode].length > 0) {
            this.allowedFields[group][mode].push("_id");
            this.allowedFields[group][mode].push("id");
            this.allowedFields[group][mode].push("__v");
          }
        }
        return this.allowedFields[group][mode];
      };
      this.mutators.find.push(function(query, socket) {
        var allowedFields, askedFields, cleanFind, i, len, realFields, s;
        if (query == null) {
          throw new Error("No query provided");
        }
        if (socket == null) {
          throw new Error("No socket provided");
        }
        allowedFields = this.getAllowedFields.bind(this)(socket, "read");
        if (!(allowedFields.length > 0)) {
          throw new Error("No permission");
        }
        if (query.find != null) {
          cleanFind = function(find) {
            var k, results, v;
            results = [];
            for (k in find) {
              v = find[k];
              if (k[0] === "$" && (v != null) && samjs.util.isObject(v)) {
                cleanFind(v);
                if (Object.keys(v).length < 1) {
                  delete find[k];
                }
              }
              if (allowedFields.indexOf(k) < 0) {
                results.push(delete find[k]);
              } else {
                results.push(void 0);
              }
            }
            return results;
          };
          cleanFind(query.find);
        }
        if (query.fields != null) {
          askedFields = query.fields.split(" ");
          realFields = [];
          for (i = 0, len = askedFields.length; i < len; i++) {
            s = askedFields[i];
            if (allowedFields.indexOf(s) > -1) {
              realFields.push(s);
            }
          }
          if (realFields.length === 0) {
            realFields = allowedFields;
          }
        } else {
          realFields = allowedFields;
        }
        query.fields = realFields.join(" ");
        return query;
      });
      processWrite = function(query, socket) {
        var allowedFields, cleanObj, k, v;
        if (query == null) {
          throw new Error("No query provided");
        }
        if (socket == null) {
          throw new Error("No socket provided");
        }
        allowedFields = this.getAllowedFields.bind(this)(socket, "write");
        if (!(allowedFields.length > 0)) {
          throw new Error("No permission");
        }
        cleanObj = {};
        for (k in query) {
          v = query[k];
          if (allowedFields.indexOf(k) > -1) {
            cleanObj[k] = v;
          }
        }
        return cleanObj;
      };
      this.mutators.update.push(function(query, socket) {
        var cond, doc, pw;
        if (!((query.cond != null) && (query.doc != null))) {
          throw new Error("Query malformed");
        }
        pw = processWrite.bind(this);
        cond = pw(query.cond, socket);
        if (!(Object.keys(cond).length > 0)) {
          throw new Error("No permission");
        }
        doc = pw(query.doc, socket);
        if (!(Object.keys(doc).length > 0)) {
          throw new Error("No permission");
        }
        return {
          cond: cond,
          doc: doc
        };
      });
      this.mutators.insert.push(processWrite);
      this.mutators.remove.push(processWrite);
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
