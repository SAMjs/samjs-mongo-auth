# out: ../lib/main.js

module.exports = (samjs) ->
  debug = samjs.debug("mongo-auth")
  throw new Error "samjs-mongo not found - must be loaded before samjs-mongo-auth" unless samjs.mongo
  throw new Error "samjs-auth not found - must be loaded before samjs-mongo-auth" unless samjs.auth

  getTree = (schema) ->
    if schema.tree
      return schema.tree
    else
      return schema

  processQuery = (obj,mode,permissionChecker,all) ->
    throw new Error "invalid socket - no auth" unless obj.socket?.client?.auth?
    throw new Error "no permission" unless all?
    user = obj.socket.client.auth.user
    props = []
    count = 0
    for k,v of getTree(@schema)
      if k == "_id" or k =="id" or k =="__v"
        continue
      count++
      perm = v[mode]
      perm ?= @[mode]
      if samjs.auth.getAllowance(user,perm,permissionChecker) == ""
        props.push k
      else
        throw new Error "no permission" if all == true or all[k]?
    if count == props.length
      return true
    else
      props.push "_id"
    return props

  samjs.mongo.plugins auth: (options) ->
    options ?= {}
    options.insertable ?= true
    options.deletable ?= false
    @addHook "beforeFind", (obj) =>
      # props = processQuery.bind(@)(obj,"read",@permissionChecker, obj.query.find)
      # if props != true
      #   if obj.query.fields? and obj.query.fields != ""
      #     fields = []
      #     for prop in obj.query.fields.split(" ")
      #       if props.indexOf(prop) > -1
      #         fields.push prop
      #   else
      #     fields = props
      #   obj.query.fields = props.join(" ")
      return obj

    @addHook "beforeInsert", (obj) =>
      if options.insertable
        all = obj.query
      else
        all = true
      processQuery.bind(@)(obj,"write",@permissionChecker, all)
      return obj

    @addHook "beforeUpdate", (obj) =>
      props = processQuery.bind(@)(obj,"read",@permissionChecker, obj.query.cond)
      if props != true
        for key,val of obj.query.cond
          return throw new Error "not allowed" if props.indexOf(key) == -1?
      props = processQuery.bind(@)(obj,"write",@permissionChecker, obj.query.doc)
      if props != true
        newDoc = {}
        for k,v of obj.query.doc
          if props.indexOf(k) > -1
            newDoc[k] = v
        obj.query.doc = newDoc
      return obj

    @addHook "beforeDelete", (obj) =>
      if options.deletable
        all = obj.query
      else
        all = true
      processQuery.bind(@)(obj,"write",@permissionChecker, true)
      return obj

    @addHook "afterCreate", ->
      if samjs.authMongo?
        tree = getTree(@schema)
        for k,v of tree
          if v?
            if v.read
              v._read = samjs.authMongo.parsePermission(v.read)
            if v.write
              v._write = samjs.authMongo.parsePermission(v.write)

  return new class MongoAuth
    name: "mongoAuth"
    getTree: getTree
