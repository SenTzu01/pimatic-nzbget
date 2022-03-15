module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  nzbget = require('nzbget-api')
  util = require('util')
  
  class NzbgetSensor extends env.devices.PresenceSensor

    constructor: (@config, @_plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = @_plugin.debug || false
      @id = @config.id
      @name = @config.name
      
      @addAttribute 'status',
        description: "NZBGet server status",
        type: t.string
        discrete: true
        acronym: "Status"
      
      @_status = lastState?.status?.value || "unknown"
      
      super()
      
      @_server = new nzbget({
        host: @config.address
        port: @config.port
        login: @config.username
        hash: @config.password
      })
      @_pullUpdatesTimeout = null
      process.nextTick(@_pullUpdates)
    
    getStatus: () => Promise.resolve(@_activity)
    
    
    _pullUpdates: () =>
      @retrieveStatus().finally( () =>
        @_pullUpdatesTimeout = setTimeout(@_pullUpdates, Math.round(@config.interval) * 1000)
      )
    
    retrieveStatus: () =>
      return new Promise( (resolve, reject) =>
        presence = false
        state = "unknown"
        @_server.status( (error, json) =>
          if error?
            @_base.error(error)
            @_setStatus("unknown")
            @_setPresence(false)
            return reject(error)
          
          @_base.debug __("JSON response: " + util.inspect(json))
          @_setPresence(true)
          @_setStatus(json.ServerStandBy && "idle" || "active")
          resolve()
        )
      )
    
    _setStatus: (status) =>
      return if @_activity is status
      @_base.debug __("status: %s", status)
      @_activity = status
      @emit('status', status)
    
    destroy: () ->
      clearTimeout(@_pullUpdatesTimeout)
      super()