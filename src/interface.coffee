# out: ../lib/interface.js
module.exports = (samjs, common) ->
  tokenStore = {}
  return (socket) ->
    socket.on "disconnect", () ->
      if socket.client?.auth?.token?
        token = socket.client.auth.token
        if tokenStore[token]
          timoutObj = setTimeout (() -> delete tokenStore[token]),
            samjs.options.tokenExpiration
          if tokenStore[token].removeTimeout
            tokenStore[token].removeTimeout()
          tokenStore[token].removeTimeout = () ->
            clearTimeout(timoutObj)
    socket.on "auth.byToken", (request) =>
      success = false
      content = false
      if request? and request.token? and request.content?
        token = request.content
        storedItem = tokenStore[token]
        if storedItem
          if storedItem.removeTimeout
            storedItem.removeTimeout()
          storedItem.resetLongTimeout()
          user = storedItem.user
          content = {}
          content[samjs.options.username] = user[samjs.options.username]
          content[samjs.options.group] = user[samjs.options.group]
          success = true
          @setLoginDate user
          socket.client.auth.user = user
          socket.client.auth.token = token
        socket.emit "auth.byToken."+request.token,
          {success: success, content: content}
    socket.on "auth", (request) =>
      if request? and request.content? and
          request.content[samjs.options.username]? and
          request.content[samjs.options.password]? and
          request.token?
        @findUser(request.content[samjs.options.username])
        .call "comparePassword", request.content[samjs.options.password]
        .then (user) =>
          return common.crypto.generateToken samjs.options.tokenSize
          .then (token) =>
            success = true
            content = {token:token}
            content[samjs.options.username] = user[samjs.options.username]
            content[samjs.options.group] = user[samjs.options.group]
            tokenStore[token] = {user:user}
            tokenStore[token].resetLongTimeout = () ->
              if timoutObj
                clearTimeout(timoutObj)
              timoutObj = setTimeout (() -> delete tokenStore[token]),
                samjs.options.tokenExpiration*50
            tokenStore[token].resetLongTimeout()
            @setLoginDate user[samjs.options.username]
            socket.client.auth.user = user
            socket.client.auth.token = token
            return content
        .then (content) -> success:true,  content: content
        .catch (e) ->      success:false, content: false
        .then (response) ->
          socket.emit "auth."+request.token, response
      else
        socket.emit "root.set." + request.token, {success:false, content: false}
