module.exports = (env) ->

  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types
  util = require('util')
  http = require('http')
  
  class NzbgetSensor extends env.devices.PresenceSensor

    constructor: (@config, @_plugin, lastState) ->
      @_base = commons.base @, @config.class
      @debug = @_plugin.debug || false
      
      @id = @config.id
      @name = @config.name
      
      @addAttribute 'active',
        description: "NZBGet server status",
        type: t.boolean
        discrete: true
        acronym: "Active"
      
      @addAttribute 'downloading',
        description: "NZBGet download status",
        type: t.boolean
        discrete: true
        acronym: "Downloading"
        
      @addAttribute 'processing',
        description: "NZBGet post-processing status",
        type: t.boolean
        discrete: true
        acronym: "Processing"
      
      @addAttribute 'speed',
        description: "NZBGet download speed",
        type: t.number
        discrete: false
        acronym: "Speed"
        unit: "MB/s"
      
      @_active = lastState?.active?.value || false
      @_downloading = lastState?.downloading?.value || false
      @_processing = lastState?.processing?.value || false
      @_speed = lastState?.speed?.value || 0
      
      super()
      
      @_pullUpdatesTimeout = null
      process.nextTick(@_pullUpdates)
    
    getActive: () => Promise.resolve(@_active)
    getDownloading: () => Promise.resolve(@_downloading)
    getProcessing: () => Promise.resolve(@_processing)
    getSpeed: () => Promise.resolve(@_speed)
    
    _pullUpdates: () =>
      timeoutMs = (s) -> return Math.round(s) * 1000
      timeout = timeoutMs(@config.interval)
      
      @retrieveStatus().catch( (error) =>
        timeout = timeoutMs(60)
      
      ).finally( () =>
        @_pullUpdatesTimeout = setTimeout(@_pullUpdates, timeout)
      )
    
    retrieveStatus: () =>
      return new Promise( (resolve, reject) =>
        presence = false
        url  = __("http://%s:%s@%s:%s/jsonrpc/status", 
                  @config.username, 
                  @config.password, 
                  @config.address, 
                  @config.port
        )
        
        http.get(url, (res) =>
          if ! /^application\/json/.test(res.headers['content-type'])
            error = new Error("Invalid Content Type. content-type: #{res.headers['content-type']}")
          
          if res.statusCode != 200
            error = new Error("Request failed. status code: #{statusCode}")
          
          if error?
            res.resume()
            @_base.error(error)
            [ "presence", 
              "active", 
              "downloading", 
              "processing"
            ].map( (property) -> @_setProperty(property, false))
            @_setProperty("speed", 0)
            reject()
          
          rawData = ''
          
          res.setEncoding('utf8')
          res.on('error', (error) =>
            @_base.error(error)
            reject()
          
          )
          res.on('data', (data) =>
            rawData += data
          
          )
          res.on('end', () =>
            json = JSON.parse(rawData).result
            @_base.debug __("JSON response: " + util.inspect(json))
            @_setPresence(true)
            @_setProperty("active", json.DownloadRate > 0 || json.PostJobCount > 0 )
            @_setProperty("downloading", json.DownloadRate > 0)
            @_setProperty("processing", json.PostJobCount > 0)
            @_setProperty("speed", json.DownloadRate / (1024*1024))
            resolve()
          )
        )
      )
    
    _setProperty: (key, value) =>
      return if @["_#{key}"] is value
      @_base.debug __("@_#{key}: %s", value)
      @["_#{key}"] = value
      @emit(key, value)
    
    destroy: () ->
      clearTimeout(@_pullUpdatesTimeout)
      super()