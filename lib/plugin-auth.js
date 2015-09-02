(function() {
  module.exports = function(samjs, common) {
    var parsePermissionInSchema;
    parsePermissionInSchema = function(schema) {
      var k, ref, tree, v;
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
          if (((ref = v.restricted) != null ? ref.allowed : void 0) != null) {
            v.restricted.allowed = common.parsePermission(v.restricted.allowed);
          }
        }
      }
      return schema;
    };
    return function() {
      var processWrite;
      this.schema = parsePermissionInSchema(this.schema);
      this.getRestrictions = function(socket) {
        var group, k, ref, ref1, tree, v;
        group = socket.client.auth.getGroup();
        if (this.restrictions == null) {
          this.restrictions = {};
        }
        if (this.restrictions[group] == null) {
          tree = common.getTree(this.schema);
          this.restrictions[group] = [];
          for (k in tree) {
            v = tree[k];
            if (((ref = v.restricted) != null ? (ref1 = ref.allowed) != null ? ref1.indexOf(group) : void 0 : void 0) < 0) {
              this.restrictions[group].push(v.restricted.find);
            }
          }
        }
        return this.restrictions[group];
      };
      this.getAllowedFields = function(socket, mode) {
        var base, group, k, ref, tree, v;
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
            if (((ref = v[mode]) != null ? ref.indexOf(group) : void 0) > -1) {
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
        var allowedFields, askedFields, cleanFind, i, len, realFields, restrictions, s;
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
        } else {
          query.find = {};
        }
        restrictions = this.getRestrictions.bind(this)(socket);
        if (restrictions.length > 0) {
          restrictions.push(query.find);
          query.find = {
            "$and": restrictions
          };
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
      return this;
    };
  };

}).call(this);
