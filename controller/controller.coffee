fs = require "fs"
async = require "async"
app = require("express")()
http = require('http').Server app
io = require('socket.io')(http)
bodyParser = require "body-parser"
redis = require "redis"
util = require 'util'

{EventEmitter} = require 'events'

Docker = require "dockerode"
docker = new Docker socketPath: '/var/run/docker.sock'

events = JSON.parse(fs.readFileSync "events.json")

app.use bodyParser()

app.get '/', (req, res) ->
  res.sendfile "./interface/tetris.html"
app.get '/tetris.js', (req, res) ->
  res.sendfile "./interface/tetris.js"
app.get '/tetris.css', (req, res) ->
  res.sendfile "./interface/tetris.css"
app.get '/tetris.ico', (req, res) ->
  res.sendfile "./interface/tetris.ico"
app.get '/key-down.gif', (req, res) ->
  res.sendfile "./interface/key-down.gif"
app.get '/key-left.gif', (req, res) ->
  res.sendfile "./interface/key-left.gif"
app.get '/key-right.gif', (req, res) ->
  res.sendfile "./interface/key-right.gif"
app.get '/key-space.gif', (req, res) ->
  res.sendfile "./interface/key-space.gif"
app.get '/key-up.gif', (req, res) ->
  res.sendfile "./interface/key-up.gif"

# go through all events defined in the events.json
engine = {}

class Context
  constructor: (@name, @options) ->
    @links = []
    @state = ""
    @events = ""
    @action = ""
    @childs = []

    io.on 'connection', (socket) =>
      socket.on @name, (msg) =>
        data = ["teemow"]
        @run data

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
  new Context event, events[event]

http.listen process.env.PORT || 5000
console.log "listening to #{process.env.PORT || 5000}"
