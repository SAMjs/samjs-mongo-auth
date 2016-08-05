# samjs-mongo-auth

Adds authorization system for [samjs-mongo](https://github.com/SAMjs/samjs-mongo).

## Getting Started
```sh
npm install --save samjs-mongo-auth
```

## Usage
```js
samjs.plugins([
  // samjs-auth and samjs-mongo are needed before samjs-mongo-auth
  require("samjs-auth"),
  require("samjs-mongo"),
  require("samjs-mongo-auth")
])
.options()
.configs()
.models({
  name: "someModel",
  db: "mongo",
  plugins: {
    auth: authOptions, // (optional) auth plugin will be enabled for all monog models by default

    // to disable auth
    noAuth: null
  },
  schema: {
    someProp: {
      type: String,
      read: true, // all can read
      write: "root" // only root can write
      }
    }
}).startup(server)
```
## authOptions
name | type | default | description
---: | --- | --- | ---
insertable | boolean | true | allows user to create documents even when access to parts of it are forbidden
deletable | boolean | false | allows user to delete documents even when access to parts of it are forbidden
