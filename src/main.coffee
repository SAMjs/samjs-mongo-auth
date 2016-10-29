# out: ../lib/main.js

module.exports = (samjs) ->
  debug = samjs.debug("mongo-auth")
  throw new Error "samjs-mongo not found - must be loaded before samjs-mongo-auth" unless samjs.mongo
  throw new Error "samjs-auth not found - must be loaded before samjs-mongo-auth" unless samjs.auth

  getProps = (user) ->
    id = samjs.auth.getIdentifier(user,@permissionChecker)
    obj = @_props[id]
    unless obj?
      obj = {
        read:
          allowed: []
          forbidden: []
        write:
          allowed: []
          forbidden: []
        }
      for mode in ["read","write"]
        for key, val of @schema.paths
          if val.options[mode]?
            perm = val.options[mode]
          else
            perm = @access[mode]
          if samjs.auth.getAllowance(user,perm,@permissionChecker) == ""
            obj[mode].allowed.push key
          else
            obj[mode].forbidden.push key
        if obj[mode].allowed.length > 0
          obj[mode].allowed.push "_id"
        else
          obj[mode].forbidden.push "_id"
      @_props[id] = obj
    return obj

  getRef = (schema, splitted) ->
    first = splitted.shift()
    schemaobj = schema.path(first)
    if splitted.length > 0
      return getRef(schemaobj.schema, splitted)
    else
      return schemaobj.options?.ref or schemaobj.caster?.options?.ref

  processAuth = (obj,mode) ->
    throw new Error "invalid socket - no auth" unless obj.socket?.client?.auth?
    user = obj.socket.client.auth.user
    if mode == "read"
      props = @getProps(user)[mode]
      if props.allowed.length > 0
        return props
    else if samjs.auth.getAllowance(user,@access[mode],@permissionChecker) == ""
      mode = "write" if ["insert","update","delete"].indexOf(mode) > -1
      return @getProps(user)[mode]
    throw new Error "no permission"

  hasForbiddenKey = (obj, forbidden) ->
    if forbidden.length > 0
      util = samjs.util
      for key, val of obj
        if util.isString(val)
          if forbidden.indexOf(key) > -1
            throw new Error "no permission"
        else if util.isArray(val)
          for obj in val
            hasForbiddenKey(obj,forbidden)
        else if util.isObject(val)
          hasForbiddenKey(val,forbidden)

  hasForbiddenProp = (str, forbidden) ->
    if forbidden.length > 0
      for prop in str.split(" ")
        if forbidden.indexOf(prop) > -1
          throw new Error "no permission"

  samjs.mongo.plugins auth: (options) ->
    options ?= {}
    @_props = {}
    @getProps = getProps.bind(@)
    @processAuth = processAuth.bind(@)

    @addHook "beforeFind", (obj) ->
      {allowed, forbidden} = @processAuth(obj,"read")
      ## find
      hasForbiddenKey(obj.query.find,forbidden)
      ## fields
      if obj.query.fields?
        hasForbiddenProp(obj.query.fields,forbidden)
      else if forbidden.length > 0
        obj.query.fields = allowed.join(" ")
      return obj

    @addHook "beforeInsert", (obj) ->
      {forbidden} = @processAuth(obj,"insert")
      hasForbiddenKey(obj.query,forbidden)
      return obj

    @addHook "afterInsert", (obj) ->
      {allowed} = @processAuth(obj,"read")
      result = {}
      for str in allowed
        result[str] = obj.result[str]
      obj.result = result
      return obj

    @addHook "beforeUpdate", (obj) ->
      forbiddenWrite = @processAuth(obj,"update").forbidden
      forbiddenRead = @processAuth(obj,"read").forbidden
      hasForbiddenKey(obj.query.cond,forbiddenRead)
      hasForbiddenKey(obj.query.doc,forbiddenWrite)
      return obj

    @addHook "beforeDelete", (obj) ->
      {forbidden} = @processAuth(obj,"delete")
      hasForbiddenKey(obj.query,forbidden)
      return obj

    @addHook "beforePopulate", (obj) ->
      for populate in obj.populate
        modelname = populate.model
        unless modelname?
          modelname = getRef(@schema, populate.path.split("."))
        if modelname? and samjs.models[modelname]?.processAuth?
          {forbidden, allowed} = samjs.models[modelname].processAuth(obj,"read")
          if populate.match?
            hasForbiddenKey(populate.match, forbidden)
          if populate.select?
            hasForbiddenProp(populate.select, forbidden)
          else if forbidden.length > 0
            populate.select = allowed.join(" ")
        else
          throw new Error "populating failed"
      return obj




  return new class MongoAuth
    name: "mongoAuth"
    hasForbiddenKey: hasForbiddenKey
    hasForbiddenProp: hasForbiddenProp
