# out: ../lib/configs.js
module.exports = (samjs, common) ->
  isAllowed = (client, mode) ->
    throw new Error("no permission") unless @[mode]
    throw new Error("invalid socket - no auth") unless client?.auth?.getGroup?
    group = client.auth.getGroup()
    @allowedFields ?= {}
    @allowedFields[group] ?= {}
    @allowedFields[group][mode] ?= @[mode].indexOf(group) > -1
    throw new Error("no permission") unless @allowedFields[group][mode]
  return {
    mutator: (options={}) ->
      if options.read?
        if options.read == true
          options.read = samjs.options.groupRoot
        options.read = common.parsePermission(options.read)
      if options.write?
        if options.write == true
          options.write = samjs.options.groupRoot
        options.write = common.parsePermission(options.write)
      return options
    test: (data,client) ->
      isAllowed.bind(@)(client,"write")
      return data
    get: (client) -> isAllowed.bind(@)(client,"read")
    set: (data, client) ->
      isAllowed.bind(@)(client,"write")
      return data
  }
