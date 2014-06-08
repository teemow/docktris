fs = require "fs"
express = require "express"
async = require "async"
http = require "http"
bodyParser = require "body-parser"

Docker = require "dockerode"
docker = new Docker socketPath: '/var/run/docker.sock'

events = JSON.parse(fs.readFileSync "events.json")


app = express()

app.use bodyParser()

Object.keys(events).forEach (event) ->
  flow = events[event]
  app.get("/#{event}", (req, res) ->
    links = []
    async.eachSeries flow, (step, cb) ->
      console.log flow, step
      options = {Image: "teemow/docktris-#{step}"}

      docker.createContainer options, (err, container) ->
        if err
          return console.log err
       
        options = {}

        if links.length > 0
          options = {Links: links.map (link) -> link.join ":"}

        container.inspect (err, data) ->
          console.log [data.Name.replace("/", ""), step]

          links.push [data.Name.replace("/", ""), step]
          console.log options
          container.start options, (err, data) ->
            cb()

    res.send "OK"
  )

app.listen process.env.PORT || 5000
console.log "listening to #{process.env.PORT || 5000}"
