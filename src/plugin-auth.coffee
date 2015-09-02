# out: ../lib/plugin-auth.js
module.exports = (samjs, common) ->
  parsePermissionInSchema = (schema) ->
    tree = common.getTree(schema)
    for k,v of tree
      if v?
        if v.read
          v.read = common.parsePermission(v.read)
        if v.write
          v.write = common.parsePermission(v.write)
        if v.restricted?.allowed?
          v.restricted.allowed = common.parsePermission(v.restricted.allowed)
    return schema

  return ->
    @schema = parsePermissionInSchema(@schema)
    @getRestrictions = (socket) ->
      group = socket.client.auth.getGroup()
      @restrictions ?= {}
      unless @restrictions[group]?
        tree = common.getTree(@schema)
        @restrictions[group] = []
        for k,v of tree
          if v.restricted?.allowed?.indexOf(group) < 0
            @restrictions[group].push(v.restricted.find)
      return @restrictions[group]
    @getAllowedFields = (socket,mode) ->
      group = socket.client.auth.getGroup()

      @allowedFields ?= {}
      @allowedFields[group] ?= {}
      unless @allowedFields[group][mode]?
        tree = common.getTree(@schema)
        @allowedFields[group][mode] = []
        for k,v of tree
          if v[mode]?.indexOf(group) > -1
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
      else
        query.find = {}
      restrictions = @getRestrictions.bind(@)(socket)
      if restrictions.length > 0
        restrictions.push(query.find)
        query.find = "$and": restrictions
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

    return @
