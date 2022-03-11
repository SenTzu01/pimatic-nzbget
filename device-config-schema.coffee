module.exports = {
  title: "pimatic-sabnzbd Device config schemas"
  NzbgetSensor: {
    title: "NZBGet Sensor device"
    description: "Sensor Device configuration"
    type: "object"
    extensions: ["xLink", "xOnLabel", "xOffLabel"]
    properties: {
      address:
        description: "The IP or address of your NZBGet server"
        type: "string"
        default: "127.0.0.1"
      port:
        description: "The TCP/IP port of your NZBGet server"
        type: "number"
        default: 6789
      user:
        description: "The userid for your NZBGet server"
        type: "string"
        required: true
      password:
        description: "The password corresponding to the NZBGet user"
        type: "string"
        required: true
      interval:
        description: "Polling interval (seconds) for update requests"
        type: "number"
        default: 10
    }
  }
}