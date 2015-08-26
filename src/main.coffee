# out: ../lib/main.js
module.exports = (samjs) ->
  common = require("./common")(samjs)
  samjs.mongo.plugins {
    auth: require("./plugin-auth")(samjs, common)
    users: require("./plugin-users")(samjs, common)
  }
  return {
    name: "auth"
    options: require("./options")
    configs: require("./configs")(samjs, common)
    models: [
      name: "users"
      schema: {}
      db: "mongo"
      plugins:
        "users": null
        "auth": null
      isRequired: true
      isExisting: ->
        for name,model of samjs.models
          if model.plugins.users?
            return true
        return false
    ]
    startup: ->
      common.debug "adding auth property to clients"
      samjs.io.use (socket,next) ->
        socket.client.auth = {
          getGroup: ->
            if socket.client.auth.user and socket.client.auth.user.group
              group =  socket.client.auth.user.group
            else
              group = samjs.options.groupDefault
          }
        next()
  }
