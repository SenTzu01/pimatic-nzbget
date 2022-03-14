module.exports = (env) ->

  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  M = env.matcher
  _ = env.require('lodash')
  assert = env.require 'cassert'
  
  class NzbgetActivityPredicateProvider extends env.predicates.PredicateProvider
    constructor: (@framework, @plugin) ->
      @debug = @plugin.config.debug ? false
      @base = commons.base @, "NzbgetActivityPredicateProvider"

    parsePredicate: (input, context) ->
      
      devices = _(@framework.deviceManager.devices).values()
        .filter((device) => device.config.class is 'NzbgetSensor').value()
      device = null
      match = null
      status = null

      M(input, context)
        .match(['status of '])
        .matchDevice(devices, (next, d) =>   
          next.match([' is ', ' reports ', ' signals '])
            .match(["active", "idle", "unknown"], (m, s) =>
              if device? and device.id isnt d.id
                context?.addError(""""#{input.trim()}" is ambiguous.""")
                return
              device = d
              status = s.trim()
              match = m.getFullMatch()
            )
        )

      if match?
        assert device?
        assert status?
        assert typeof match is "string"
        return {
          token: match
          nextInput: input.substring(match.length)
          predicateHandler: new NzbgetActivityPredicateHandler(device, status, @plugin)
        }
      else
        return null

  class NzbgetActivityPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@device, @status, plugin) ->
      @debug = plugin.config.debug ? false
      @base = commons.base @, "NzbgetActivityPredicateHandler"
      @dependOnDevice(@device)

    setup: ->
      @statusListener = (status) =>
        @base.debug "Checking if current state #{status} matches #{@status}"
        @emit 'change', true if @status is status

      @device.on 'status', @statusListener
      super()

    getValue: ->
      @device.getUpdatedAttributeValue('status').then( (status) =>
        return status
      )

    destroy: ->
      @device.removeListener 'status', @statusListener
      super()

    getType: -> 'status'
    
  return NzbgetActivityPredicateProvider