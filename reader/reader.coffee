redis = require "redis"

client = redis.createClient 6379, process.env.STATE_PORT_6379_TCP_ADDR
events = redis.createClient 6379, process.env.EVENTS_PORT_6379_TCP_ADDR

client.keys "*", (err, replies) ->
  fetch = 0
  read = {}

  replies.forEach (key) ->
    client.get key, (err, data) ->
      read[key] = data
      fetch++

      if fetch is replies.length
        payload =
          event: "read"
          data: read

        events.publish "docktris", "#{JSON.stringify(payload)}"
        client.end()
        events.end()

