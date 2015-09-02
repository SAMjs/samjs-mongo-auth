# out: ../lib/plugin-users.js
module.exports = (samjs, common) ->
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
    @interfaces.auth ?= []
    @interfaces.auth.push authInterface
    @test = (value) ->
      new samjs.Promise (resolve, reject) =>
        @dbModel.count {group:samjs.options.groupRoot}, (err, data) ->
          return reject err if err?
          if data == 0
            return reject "no #{samjs.options.groupRoot} found"
          resolve()
    @installInterface = (socket) ->
      socket.on "root.set", (request) =>
        if request?.content? and
            request.token? and request.content[samjs.options.username]? and
            request.content[samjs.options.password]?
          request.content.group = samjs.options.groupRoot
          created = new Promise (resolve, reject) =>
            @dbModel.create request.content, (err) ->
              return reject err if err?
              resolve()
          .then -> success:true, content:false
          .catch (e) -> success:false, content:e?.message
          .then (response) ->
            socket.emit "root.set." + request.token, response
            if response.success
              common.debug "user installed completely"
              samjs.emit "checkInstalled"
          return created
        else
          socket.emit "root.set." + request.token,
            {success:false, content: "Username and password required"}
      return ->
        if socket?
          socket.removeAllListeners "root.set"
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
