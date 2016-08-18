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
    if @[mode]?
      return samjs.auth.isAllowed(obj.client,@[mode],permissionChecker)
    else
      throw new Error "invalid socket - no auth" unless obj.client.auth?
      throw new Error "no permission" unless all?
      user = obj.client.auth.user
      props = []
      count = 0
      for k,v of getTree(@schema)
        count++
        if k == "_id" or k =="id" or k =="__v"
          continue
        if samjs.auth.getAllowance(user,v[mode],permissionChecker) == ""
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
      props = processQuery.bind(@)(obj,"read",@permissionChecker, obj.query.find)
      if props != true
        if obj.query.fields? and obj.query.fields != ""
          fields = []
          for prop in obj.query.fields.split(" ")
            if props.indexOf(prop) > -1
              fields.push prop
        else
          fields = props
        obj.query.fields = props.join(" ")
      return obj

    @addHook "beforeInsert", (obj) =>
      if options.insertable
        all = obj.query
      else
        all = true
      processQuery.bind(@)(obj,"write",@permissionChecker, all)
      return obj

    @addHook "beforeUpdate", (obj) =>
      props = processQuery.bind(@)(obj,"write",@permissionChecker, obj.query.cond)
      if props != true
        newDoc = {}
        for k,v of obj.query.doc
          if props.indexOf(k) > -1
            newDoc[k] = v
        obj.query.doc = newDoc
      return obj

    @addHook "beforeRemove", (obj) =>
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
