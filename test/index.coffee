chai = require "chai"
should = chai.should()
chai.use require "chai-as-promised"
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
  before ->
    fs.unlinkAsync testConfigFile
    .catch -> return true
    .finally ->
      samjs.reset().then ->
        samjs.plugins(samjsAuth(),samjsMongo,samjsMongoAuth)
        .options({config:testConfigFile})
        .configs()
        .models({
          name:"testModel"
          db:"mongo"
          schema: (Schema) ->
            someProp:String
            link:
              type: Schema.Types.ObjectId
              ref: "testModel2"
          access:
            read: "root"
            write: "root"
        },{
          name:"testModel2"
          db:"mongo"
          access:
            read: "root"
            write: "root"
          schema: (Schema) ->
            someProp:
              type: String
            link:
              type: Schema.Types.ObjectId
            hidden:
              type: String
              read: false
        },{
          name:"testModel3"
          db:"mongo"
          access:
            read: "root"
            write: "root"
          schema:
            someProp:
              type: String
              read: true
        })

  describe "mongoAuth", ->
    model = null
    model2 = null
    model3 = null
    describe "startup", ->
      it "should configure", ->
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

      it "should be started up",  ->
        samjs.state.onceStarted

      it "should reject model.insert",  ->
        model = client.getMongoModel("testModel")
        model.insert({name:"root",pwd:"newpwd"})
        .should.be.rejected
      it "should reject model.find",  ->
        model.find().should.be.rejected
      it "should reject model.count",  ->
        model.count().should.be.rejected
      it "should reject model.delete",  ->
        model.delete({name:"root"}).should.be.rejected

      it "should reject model.update",  ->
        model.update(cond:{group:"root"}, doc: {pwd:"newpwd"})
        .should.be.rejected

      it "should work with model2", ->
        model2 = client.getMongoModel("testModel2")
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
          model2.delete({someProp:"test"})
        .should.be.rejected

      it "should work with model3", ->
        model3 = client.getMongoModel("testModel3")
        model3.insert({someProp:"test"})
        .then (result) ->
          should.not.exist result
        .catch (e) ->
          model3.find(find:{})
          .then (result) ->
            return model3.update(cond:{someProp:"test"}, doc: {someProp:"test2"})
            .catch (e) ->
              return model3.delete({someProp:"test"}).should.be.rejected




      it "should auth",  ->
        client.auth.login {name:"root",pwd:"rootroot"}
        .then (result) ->
          result.name.should.equal "root"

      describe "once authenticated", ->
        it "should model.insert", ->
          model.insert({someProp:"test"})
          .then (result) ->
            should.exist result._id

        it "should model.find", ->
          model.find(find:{someProp:"test"})
          .then (result) ->
            result = result[0]
            should.exist result._id
            should.exist result.someProp
            result.someProp.should.equal "test"

        it "should model.count", ->
          model.count({someProp:"test"})
          .then (result) ->
            result.should.equal 1

        it "should model.update",  ->
          model.update(cond:{someProp:"test"}, doc: {someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1
            model.find(find: result[0])
          .then (result) ->
            result[0].someProp.should.equal "test2"
        it "should model.delete", ->
          model.delete({someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1

        it "should work with model2",  ->
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
            model2.delete({someProp:"test"})
          .then (result) ->
            result.length.should.equal 1

        it "should work with model3", ->
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
            model3.delete({someProp:"test2"})
          .then (result) ->
            result.length.should.equal 1

        it "should work with populate", ->
          model2.insert({someProp:"test",hidden:"hiddentest"})
          .then (result) -> model.insert({link:result._id,someProp:"test2"})
          .then -> model.find(find:{},populate:'link')
          .then (result) ->
            result = result[0]
            should.exist result.link
            should.exist result.link.someProp
            should.not.exist result.link.hidden
            result.link.someProp.should.equal "test"
            model2.update({cond:{_id:result.link._id},doc:{link:result._id}})
          .then -> model2.find(find:{},populate:{path:"link",model:"testModel"})
          .then (result) ->
            result = result[0]
            should.exist result.link
            should.exist result.link.someProp
            result.link.someProp.should.equal "test2"
            samjs.Promise.all [model.delete({}),model2.delete({})]


  after ->
    if samjs.models.testModel?
      model1 = samjs.models.testModel.dbModel
      model2 = samjs.models.testModel2.dbModel
      model3 = samjs.models.testModel3.dbModel
      samjs.Promise.all([model1.remove({}),model2.remove({}),model3.remove({})])
      .then ->
        return samjs.shutdown() if samjs.shutdown?
    else if samjs.shutdown?
      samjs.shutdown()
