chai = require "chai"
should = chai.should()
samjs = require "../src"
Promise = require "bluebird"
helper = require("./helper")(samjs)




describe "samjs", ->
  client = null
  auth = null
  before ->
    samjs.reset()

  describe "authentification", ->
    before (done) ->
      helper.install(3032)
      .then (samjsClient) ->
        client = samjsClient
        done()
      .catch done

    after (done) ->
      helper.uninstall()
      .then (result) ->
        done()


    it "should authenticate", (done) ->
      auth = client.authentification
      auth.login helper.user
      .then (result) ->
        name = helper.user[samjs.options.names.username]
        result[samjs.options.names.username].should.equal name
        result[samjs.options.names.group].should.equal samjs.options.groupRoot
        samjs.io.nsps["/auth"].sockets[0]
          .client.auth.user[samjs.options.names.username].should.equal name
        auth.authenticated.should.be.true
        auth.token.should.exist
        done()
      .catch done

    it "should work with tokens", (done) ->
      samjs.io.nsps["/auth"].sockets[0].client.auth.user = null
      auth.authenticated = false
      auth.login()
      .then (result) ->
        name = helper.user[samjs.options.names.username]
        result[samjs.options.names.username].should.equal name
        result[samjs.options.names.group].should.equal samjs.options.groupRoot
        samjs.io.nsps["/auth"].sockets[0]
          .client.auth.user[samjs.options.names.username].should.equal name
        auth.authenticated.should.be.true
        done()
      .catch done

    it "should reject with wrong token", (done) ->
      samjs.io.nsps["/auth"].sockets[0].client.auth.user = null
      auth.authenticated = false
      auth.token = "something"
      auth.login()
      .catch (error) ->
        error.message.should.equal "false"
        done()

    it "should reject wrong user", (done) ->
      samjs.io.nsps["/auth"].sockets[0].client.auth.user = null
      auth.authenticated = false
      auth.token = null
      user = {}
      user[samjs.options.names.username] = "root"
      user[samjs.options.names.password] = "something"
      auth.login user
      .catch (error) ->
        error.message.should.equal "false"
        done()
