module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  nzbget = require('@jc21/nzbget-jsonrpc-api').Client
  util = require('util')
  
  class NzbgetSensor extends env.devices.PresenceSensor

    constructor: (@config, @_plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = @_plugin.debug || false
      @id = @config.id
      @name = @config.name
      
      @addAttribute 'status',
        description: "NZBGet status status",
        type: t.string
        discrete: true
        acronym: "Status"
      
      @_status = lastState?.status?.value || "unknown"
      
      super()
      @_status = {
        Idle: "idle"
        Active: "active"
        Unknown: "Unknown"
      }
      
      url = "http://#{@config.user}:#{@config.password}@#{@config.address}:#{@config.port}/jsonrpc"
      @_server = new nzbget(url)
      @_pullUpdatesTimeout = null
      @_pullUpdates()
      
    
    getStatus: () => Promise.resolve(@_activity)
    
    
    _pullUpdates: () =>
      @retrieveStatus()
      @_pullUpdatesTimeout = setTimeout(@_pullUpdates, Math.round(@config.interval) * 1000)
    
    retrieveStatus: () =>
      presence = false
      state = "unknown"
      @_server.status().then( (status) =>
        @_base.debug __("nzbget.status: " + util.inspect(status))
        presence = true
        state = "active"
        state = "idle" if status.ServerStandBy
        
      ).catch( (error) =>
        presence = false
        state = "unknown"
      
      ).finally( () =>
        @_setPresence(presence)
        @_setStatus(state)
      )
    
    _setStatus: (status) =>
      return if @_activity is status
      @_base.debug __("status: %s", status)
      @_activity = status
      @emit('status', status)
    
    destroy: () ->
      clearTimeout(@_pullUpdatesTimeout)
      super()