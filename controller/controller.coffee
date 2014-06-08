fs = require "fs"
express = require "express"
async = require "async"
http = require "http"
bodyParser = require "body-parser"
redis = require "redis"

Docker = require "dockerode"
docker = new Docker socketPath: '/var/run/docker.sock'

events = JSON.parse(fs.readFileSync "events.json")


app = express()

app.use bodyParser()

# go through all events defined in the events.json
engine = {}

class Context
  constructor: (@name, @options) ->
    @links = []
    @state = ""
    @events = ""
    @action = ""
    @childs = []

    app.get("/#{@name}", (req, res) =>
      data = JSON.parse(req.param 'data')

      @run data
      res.send "OK"
    )

    if @options.events
      Object.keys(@options.events).forEach (event) =>
        @childs[event] = new Context event, @options.events[event]

  run: (data) ->
    @create_channel () =>
      console.log "channel created"

      console.log "create state"
      @create_state () =>
        console.log "create action"

        if not data
          data = []

        data.unshift @state
        @create_action data, () =>
          console.log "done"

  create_action: (data, cb) ->
    options = 
      Cmd: data

    @create_container @options.action, options, @links, () =>
      cb()

  create_state: (cb) ->
    if not @options.context
      cb()

    @create_container @options.context, {}, [], (err, container) =>
      @links.push [container.Name.replace("/", ""), @options.context]
      @state = container.Id
      cb()

  create_channel: (cb) ->
    @create_container "events", {}, [], (err, container) =>
      @links.push [container.Name.replace("/",""), "events"]
      @events = container.Id

      pubsub = redis.createClient 6379, container.NetworkSettings.IPAddress
      pubsub.on "error", (err) =>
        console.log err

      pubsub.subscribe "docktris"
      pubsub.on "message", (channel, message) =>
        console.log message
        msg = JSON.parse message

        @childs[msg.event].run msg.data, () =>
          console.log "event done"

      pubsub.on "subscribe", () =>
        cb()

  create_container: (image, options, links, cb) ->
    options.Image = "teemow/docktris-#{image}"
    console.log "start container #{options.Image}"
    docker.createContainer options, (err, container) =>
      console.log "started"
      if err
        return console.log err

      options = {}

      if links.length > 0
        options = {Links: links.map (link) => link.join ":"}

      container.start options, (err, data) =>
        container.inspect (err, data) =>
          cb(err, data) if cb

Object.keys(events).forEach (event) ->
  context = new Context event, events[event]

app.listen process.env.PORT || 5000
console.log "listening to #{process.env.PORT || 5000}"
