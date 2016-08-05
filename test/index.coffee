chai = require "chai"
should = chai.should()
samjs = require "samjs"
samjsClient = require "samjs-client"
samjsMongo = require "samjs-mongo"
samjsMongoClient = require "samjs-mongo-client"
samjsAuth = require "samjs-auth"
samjsAuthClient = require "samjs-auth-client"
samjsMongoAuth = require("../src/main")




fs = samjs.Promise.promisifyAll(require("fs"))
port = 3050
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"
mongodb = "mongodb://localhost/test"

describe "samjs", ->
  client = null
  before (done) ->
    fs.unlinkAsync testConfigFile
    .catch -> return true
    .finally ->
      samjs.reset()
      .plugins(samjsAuth,samjsMongo,samjsMongoAuth)
      .options({config:testConfigFile})
      .configs()
      .models({
        name:"testModel"
        db:"mongo"
        schema:
          someProp:String
        read: "root"
        write: "root"
      },{
        name:"testModel2"
        db:"mongo"
        schema:
          someProp:
            type: String
            read: "root"
            write: "root"
          hidden:
            type: String
            read: false
            write: "root"
      },{
        name:"testModel3"
        db:"mongo"
        schema:
          someProp:
            type: String
            read: true
            write: "root"
      })
      done()

  describe "mongoAuth", ->
    model = null
    model2 = null
    model3 = null
    describe "startup", ->
      it "should configure", (done) ->
        samjs.startup().io.listen(port)
        client = samjsClient({
          url: url
          ioOpts:
            reconnection: false
            autoConnect: false
          })()
        client.plugins(samjsAuthClient,samjsMongoClient)
        client.install.onceConfigure
        .return client.install.set "mongoURI", mongodb
        .return client.auth.createRoot "rootroot"
        .then -> done()
        .catch done
      it "should be started up", (done) ->
        samjs.state.onceStarted
        .then -> done()
        .catch done
      it "should reject model.insert", (done) ->
        model = new client.Mongo("testModel")
        model.insert({name:"root",pwd:"newpwd"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          done()
      it "should reject model.find", (done) ->
        model.find()
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          done()
      it "should reject model.count", (done) ->
        model.count()
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          done()
      it "should reject model.remove", (done) ->
        model.remove({name:"root"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          done()

      it "should reject model.update", (done) ->
        model.update(cond:{group:"root"}, doc: {pwd:"newpwd"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          done()
      it "should work with model2", (done) ->
        model2 = new client.Mongo("testModel2")
        model2.insert({someProp:"test",hidden:"hiddentest"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          model2.find()
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          model2.update(cond:{someProp:"test"}, doc: {hidden:"hiddentest2"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          model2.remove({someProp:"test"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          done()
      it "should work with model3", (done) ->
        model3 = new client.Mongo("testModel3")
        model3.insert({someProp:"test"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          model3.find(find:{})
        .then (result) ->
          model3.update(cond:{someProp:"test"}, doc: {someProp:"test2"})
          .then (result) ->
            should.not.exist result
          .catch (e) ->
            model3.remove({someProp:"test"})
          .then (result) ->
            should.not.exist result
          .catch (e) ->
            done()
        .catch done

      it "should auth", (done) ->
        client.auth.login {name:"root",pwd:"rootroot"}
        .then (result) ->
          result.name.should.equal "root"
          done()
        .catch done
      describe "once authenticated", ->
        it "should model.insert", (done) ->
          model.insert({someProp:"test"})
          .then (result) ->
            should.exist result._id
            done()
          .catch done
        it "should model.find", (done) ->
          model.find(find:{someProp:"test"})
          .then (result) ->
            result = result[0]
            should.exist result._id
            should.exist result.someProp
            result.someProp.should.equal "test"
            done()
          .catch done

        it "should model.count", (done) ->
          model.count({someProp:"test"})
          .then (result) ->
            result.should.equal 1
            done()
          .catch done
        it "should model.update", (done) ->
          model.update(cond:{someProp:"test"}, doc: {someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1
            model.find(find: result[0])
          .then (result) ->
            result[0].someProp.should.equal "test2"
            done()
          .catch done
        it "should model.remove", (done) ->
          model.remove({someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1
            done()
          .catch done
        it "should work with model2", (done) ->
          model2.insert({someProp:"test",hidden:"hiddentest"})
          .then (result) ->
            should.exist result._id
            model2.find()
          .then (result) ->
            result = result[0]
            should.exist result._id
            should.exist result.someProp
            should.not.exist result.hidden
            result.someProp.should.equal "test"
            model2.update(cond:{someProp:"test"}, doc: {hidden:"hiddentest2"})
          .then (result) ->
            result.length.should.equal 1
            model2.remove({someProp:"test"})
          .then (result) ->
            result.length.should.equal 1
            done()
          .catch done
        it "should work with model3", (done) ->
          model3.insert({someProp:"test"})
          .then (result) ->
            should.exist result._id
            model3.find()
          .then (result) ->
            result = result[0]
            should.exist result._id
            should.exist result.someProp
            result.someProp.should.equal "test"
            model3.update(cond:{someProp:"test"}, doc: {someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1
            model3.remove({someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1
            done()
          .catch done
  after (done) ->
    if samjs.shutdown?
      if samjs.models.testModel?
        model1 = samjs.models.testModel.dbModel
        model2 = samjs.models.testModel2.dbModel
        model3 = samjs.models.testModel3.dbModel
        samjs.Promise.all([model1.remove({}),model2.remove({}),model3.remove({})])
        .then -> done()
      else
        samjs.shutdown().then -> done()
    else
      done()
