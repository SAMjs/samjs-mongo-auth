# out: ../lib/common.js
module.exports = (samjs) ->
  return new class Common
    constructor: ->
      @debug = samjs.mongo.debug("auth")
      @crypto = require("./crypto")(samjs)
    getTree: (schema) ->
      if schema.tree
        return schema.tree
      else
        return schema
    parsePermission: (permission) ->
      unless samjs.util.isArray(permission)
        if samjs.options.hierarchical
          i = samjs.options.groups.indexOf(permission)
          permission = samjs.options.groups.slice i
        else
          permission = [permission]
      return permission
