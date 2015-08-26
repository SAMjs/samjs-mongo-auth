# out: ../lib/plugin-users.js
module.exports = (samjs, common) -> return ->
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
  return @
