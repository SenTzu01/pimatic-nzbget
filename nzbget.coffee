module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  
  deviceConfigTemplates = [
    {
      "name": "NZBGet Sensor Device",
      "class": "NzbgetSensor"
    }
  ]
  
  actionProviders = []
  
  predicateProviders = [
    'nzbget-activity-predicate'
  ]
  
  class NzbgetPlugin extends env.plugins.Plugin
    constructor: () ->
      
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @_base = commons.base @, 'Plugin'
      
      deviceConfigDef = require("./device-config-schema")
      
      for device in deviceConfigTemplates
        className = device.class
        # convert camel-case classname to kebap-case filename
        filename = className.replace(/([a-z])([A-Z])/g, '$1-$2').toLowerCase()
        classType = require('./devices/' + filename)(env)
        @_base.debug "Registering device class #{className}"
        @framework.deviceManager.registerDeviceClass(className, {
          configDef: deviceConfigDef[className],
          createCallback: @_callbackHandler(className, classType)
        })
      
      for provider in actionProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) ->
          $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./actions/' + provider)(env)
        @_base.debug "Registering action provider #{className}"
        @framework.ruleManager.addActionProvider(new classType @framework, @)
      
      for provider in predicateProviders
        className = provider.replace(/(^[a-z])|(\-[a-z])/g, ($1) ->
          $1.toUpperCase().replace('-','')) + 'Provider'
        classType = require('./predicates/' + provider)(env)
        @_base.debug "Registering predicate provider #{className}"
        @framework.ruleManager.addPredicateProvider(new classType @framework, @)
      
      @framework.deviceManager.on('discover', () =>
      )
    
    _destroy: () ->
      super()
    
    _callbackHandler: (className, classType) ->
      return (config, lastState) =>
        return new classType(config, @, lastState, @framework)
  
  return new NzbgetPlugin