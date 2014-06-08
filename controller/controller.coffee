fs = require "fs"
express = require "express"
async = require "async"
http = require "http"
bodyParser = require "body-parser"
redis = require "redis"
util = require 'util'

{EventEmitter} = require 'events'

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

    setInterval =>
      @create_reader()
    , 10000

    @create_channel () =>
      console.log "channel created"

      console.log "create state"
      @create_state () =>
        console.log "create action"

        if not data
          data = []

        data.unshift @state
        @create_action data, () =>
          true

  create_reader: () ->
    @create_container "reader", {}, @links, () ->
      true

  create_action: (data, cb) ->
    options = 
      Cmd: data

    @create_container @options.action, options, @links, () =>
      cb()

  create_state: (cb) ->
    if not @options.context
      cb()

    @create_container @options.context, {}, [], (err, container) =>
      @links.push [container.Name.replace("/", ""), "state"]
      @state = container.Id
      cb()

  create_channel: (cb) ->
    @create_container "events", {}, [], (err, container) =>
      @links.push [container.Name.replace("/",""), "events"]
      @events = container.Id

      pubsub = redis.createClient 6379, container.NetworkSettings.IPAddress
      pubsub.on "error", (err) =>

      pubsub.subscribe "docktris"
      pubsub.on "message", (channel, msg) =>
        if typeof msg isnt 'object'
          msg = JSON.parse msg

        if msg.event is "read"
          console.log @state, msg.data
        else
          @childs[msg.event].run msg.data

      pubsub.on "subscribe", () =>
        cb()

  create_container: (image, options, links, cb) ->
    options.Image = "teemow/docktris-#{image}"
    docker.createContainer options, (err, container) =>
      if err
        return console.log err

      options = {}

      if links.length > 0
        options = {Links: links.map (link) => link.join ":"}

      container.start options, (err, data) =>
        container.inspect (err, data) =>
          cb(err, data) if cb

          container.wait () ->
            container.remove () ->

  wait_for_container: (container) ->

Object.keys(events).forEach (event) ->
  context = new Context event, events[event]

app.listen process.env.PORT || 5000
console.log "listening to #{process.env.PORT || 5000}"
