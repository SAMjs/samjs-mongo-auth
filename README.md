# samjs-mongo-auth

Authentification module for the mongo plugin for samjs.

Client: [samjs-mongo-auth-client](https://github.com/SAMjs/samjs-mongo-auth-client)

## Example
```coffee
samjs = require "samjs"

samjs.plugins(require("samjs-mongo"),require("samjs-mongo-auth"))
.options({config:"config.json"})
.configs()
.models({
  name: "someModel"
  db: "mongo"
  plugins:
    auth: null
  schema:
    someProp:
      type: String
      read: "all"
      write: "root"
}).startup().io.listen(3000)

#will be in config mode, then in install mode, after install:
samjs.started.then -> # not in install mode anymore

#client in browser

samjs = require("samjs-client")({url: window.location.host+":3000/"})
samjs.plugins(require "samjs-mongo-client",require "samjs-mongo-auth-client")

## when mongoURI isn't setted within config.json, samjs will go into
## config mode, there you can set it
samjs.install.set "mongoURI", "mongodb://localhost/tableName"
.then -> #success
.catch -> #failed

## afterwards it goes into install mode, as at least one root user is required
samjs.auth.install({name:"username",pwd:"somepwd"})
.then -> #success
.catch -> #failed

someModel = new samjs.Mongo("someModel")
# has insert / count / find / update / remove
someModel.insert someProp:"someValue"
.catch -> #will fail, not authenticated
samjs.auth.login {name:"username",pwd:"somepwd"}
.then -> #success
  someModel.insert someProp:"someValue"
  .then -> #will work now
samjs.on "login", ->
  # fired on successfull login
```
