# out: ../lib/options.js
module.exports = {
  hierarchical: true
  groups: [
    "all"
    "user"
    "root"
  ]
  groupDefault: "all"
  groupRoot: "root"
  saltWorkFactor: 10
  tokenExpiration: 1000*60*30 # 30 minutes
  tokenSize: 48
  username: "name"
  password: "pwd"
  group: "group"
  loginDate: "loginDate"
}
