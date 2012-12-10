express = require('express')
http = require('http')
path = require('path')
io = require('socket.io')

_ = require('underscore')
PaintingPosition = require('./painting/position')
Player = require('./player')
Map = require('./map')

tilePositions = require './map/tile_positions'
browserify = require('browserify')(
  watch: true
  debug: true
)

app = express()
server = http.createServer(app)
io = io.listen(server)
io.set('log level', 2)

app.configure ->
  app.set('port', process.env.PORT || 9000)
  app.set('views', __dirname + '/views')
  app.set('view engine', 'jade')

  app.use express.logger('dev')
  app.use express.bodyParser()
  app.use express.methodOverride()
  app.use app.router
  app.use express.static(path.join(__dirname, '..', 'public'))

  browserify.register '.html', (body) ->
    compiled = body.replace(/\"/g, "\\\"").replace(/\n/g, '\\\n')
    "module.exports = \"#{compiled}\""

  browserify.addEntry(__dirname + '/../client/node_modules/init/bootstrap.coffee')
  app.use browserify

app.configure 'development', ->
  app.use express.errorHandler()

createGame = (sockets) ->
  highScores =
    guards: 0
    thieves: 0
    all: {}
    ordered: []

  addScore = (score) ->
    if score.isGuard
      highScores.guards += 1
    else
      highScores.thieves += 1

    theScore = highScores.all[score.id]
    if !theScore?
      highScores.all[score.id] = theScore =
        id: score.id
        isGuard: score.isGuard
        name: score.name
        value: 0

    theScore.value += 1

    sortScores()

  sortScores = ->
    ordered = []

    for id, score of highScores.all
      ordered.push score

    highScores.ordered = _.sortBy ordered, (s) ->
      s.value * -1

  currentId = 0
  currentPaintingId = 0
  isGuard = false
  paintingPositions = {}
  map = new Map tilePositions: tilePositions.dungeon

  spawnPlayer = (isGuard) ->
    id = currentId++

    coords = map.getRandomSpawnCoordinates()
    new Player
      id: id
      x: coords.x
      y: coords.y
      isGuard: isGuard

  spawnPainting = ->
    id = currentPaintingId++
    coords = map.getRandomSpawnCoordinates()
    paintingPositions[id] = new PaintingPosition id: id, x: coords.x, y: coords.y

  _.range(5).forEach ->
    spawnPainting()

  sockets.on 'connection', (socket) ->
    isGuard = map.needMoreGuards()
    player = spawnPlayer(isGuard)
    socket.emit 'init',
      opponents: map.players
      player: player
      map: tilePositions.dungeon
      paintings: paintingPositions
      scores: highScores

    map.players[player.id] = player

    socket.broadcast.emit 'player:connected', player.toHash()

    socket.on 'player:update', (data) ->
      player.orient(data.direction)
      player.x = data.x
      player.y = data.y

      socket.broadcast.emit 'player:update', player.toHash()

    socket.on 'player:name-change', (name) ->
      player.name = name
      socket.broadcast.emit 'player:name-change', player.id, name

    socket.on 'disconnect', ->
      delete map.players[player.id]
      socket.broadcast.emit('player:disconnected', id: player.id)

    socket.on 'player:remove', (playerId) ->
      socket.broadcast.emit 'player:disconnected', id: playerId
      socket.disconnect()

    socket.on 'painting:pickedUp', (paintingId, playerId) ->
      if (painting = paintingPositions[paintingId]) && (thisPlayer = map.players[playerId])
        painting.playerId = thisPlayer.id
        socket.broadcast.emit 'painting:pickedUp', paintingId, playerId

    socket.on 'painting:dropped', (paintingId, playerId) ->
      if (painting = paintingPositions[paintingId]) && (thisPlayer = map.players[playerId])
        painting.playerId = null
        socket.broadcast.emit 'painting:dropped', paintingId, playerId

    socket.on 'painting:moved', (paintingId, coords) ->
      if painting = paintingPositions[paintingId]
        painting.x = coords.x
        painting.y = coords.y
        socket.broadcast.emit 'painting:moved', paintingId, coords

    socket.on 'painting:removed', (paintingId) ->
      if paintingPositions[paintingId]
        delete paintingPositions[paintingId]
        socket.broadcast.emit 'painting:removed', paintingId
        sockets.emit 'painting:spawned', spawnPainting()

    socket.on 'score:update', (score) ->
      addScore(score)
      sockets.emit 'score:update', highScores

  map.players

index = (req, res) ->
  res.render('index', { title: 'Castle Riot' })

games = {}
gameCounter = 0
newGame = (req, res) ->
  return if games[req.path]
  sockets = io.of(req.path)
  games[req.path] = createGame(sockets)

app.get '/', (req, res) ->
  for reqPath, players of games
    if _.keys(players).length < 20
      res.redirect(reqPath)
      return
  res.redirect("/#{gameCounter++}")

app.get /^\/\d+/, (req, res) ->
  newGame(req, res)
  index(req, res)

server.listen app.get('port'), ->
  console.log("Express server listening on port " + app.get('port'))

