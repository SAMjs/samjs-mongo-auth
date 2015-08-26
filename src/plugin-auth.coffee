# out: ../lib/model-auth.js
module.exports = (samjs, common) ->
  parsePermissionInSchema = (schema) ->
    tree = common.getTree(schema)
    for k,v of tree
      if v?
        if v.read
          v.read = common.parsePermission(v.read)
        if v.write
          v.write = common.parsePermission(v.write)
    return schema
  authInterface = require("./interface")(samjs, common)
  return (options) ->
    options ?= {}
    options.read ?= samjs.options.groupRoot
    options.write ?= samjs.options.groupRoot
    options.read = common.parsePermission(options.read)
    options.write = common.parsePermission(options.write)
    properties = {}
    properties[samjs.options.username] = {
      type: String
      required: true
      index:
        unique: true
      read: options.read
      write: options.write
    }
    properties[samjs.options.password] = {
      type: String
      required: true
      write: options.write
    }
    properties[samjs.options.group] = {
      type: String
      required: true
      read: options.read
      write: options.write
    }
    properties[samjs.options.loginDate] = {
      type: Date
      read: options.read
      write: options.write
    }
    @schema.add(properties)
    @schema.pre "save", (next) ->
      common.crypto.generateHashedPassword(@,next)
    @schema.methods.comparePassword = (providedPassword) ->
      return common.crypto.comparePassword providedPassword, @[samjs.options.password]
        .then => return @
    @schema = parsePermissionInSchema(@schema)
    @interfaces.auth = authInterface
    @getAllowedFields = (socket,mode) ->
      group = socket.client.auth.getGroup()

      @allowedFields ?= {}
      @allowedFields[group] ?= {}
      unless @allowedFields[group][mode]?
        tree = common.getTree(@schema)
        @allowedFields[group][mode] = []
        for k,v of tree
          if v[mode]? and v[mode].indexOf(group) > -1
            @allowedFields[group][mode].push(k)
        if @allowedFields[group][mode].length > 0
          @allowedFields[group][mode].push("_id")
          @allowedFields[group][mode].push("id")
          @allowedFields[group][mode].push("__v")
      return @allowedFields[group][mode]
    @mutators.find.push (query, socket) ->
      throw new Error("No query provided") unless query?
      throw new Error("No socket provided") unless socket?
      allowedFields = @getAllowedFields.bind(@)(socket, "read")
      throw new Error("No permission") unless allowedFields.length > 0
      if query.find?
        cleanFind = (find) ->
          for k,v of find
            if k[0] == "$" and v? and samjs.util.isObject(v)
              cleanFind v
              if Object.keys(v).length < 1
                delete find[k]
            if allowedFields.indexOf(k) < 0
              delete find[k]
        cleanFind query.find
      if query.fields?
        askedFields = query.fields.split(" ")
        realFields = []
        for s in askedFields
          if allowedFields.indexOf(s) > -1
            realFields.push(s)
        if realFields.length == 0
          realFields = allowedFields
      else
        realFields = allowedFields
      query.fields = realFields.join(" ")
      return query
    processWrite = (query, socket) ->
      throw new Error("No query provided") unless query?
      throw new Error("No socket provided") unless socket?
      allowedFields = @getAllowedFields.bind(@)(socket, "write")
      throw new Error("No permission") unless allowedFields.length > 0
      cleanObj = {}
      for k,v of query
        if allowedFields.indexOf(k) > -1
          cleanObj[k] = v
      return cleanObj
    @mutators.update.push (query,socket) ->
      throw new Error("Query malformed") unless query.cond? and query.doc?
      pw = processWrite.bind(@)
      cond = pw(query.cond,socket)
      throw new Error("No permission") unless Object.keys(cond).length > 0
      doc = pw(query.doc,socket)
      throw new Error("No permission") unless Object.keys(doc).length > 0
      return cond: cond, doc: doc
    @mutators.insert.push processWrite
    @mutators.remove.push processWrite
    @findUser = (userName) ->
      find = {}
      find[samjs.options.username] = userName
      return new samjs.Promise (resolve, reject) =>
        @dbModel.findOne(find).exec()
          .then resolve, reject
    @setLoginDate = (userName) ->
      find = {}
      find[samjs.options.username] = userName
      update = {}
      update[samjs.options.loginDate] = Date.now()
      return new samjs.Promise (resolve, reject) =>
        @dbModel.update find, update, (err) ->
          return reject err if err?
          resolve()
    return @
