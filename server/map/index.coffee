TileMap = require '../jaws/tile_map'
_ = require 'underscore'

module.exports = class Map
  constructor: ({ @tilePositions, @height, @width }) ->
    @height ?= 30
    @width ?= 50
    @cellSize = 32
    @blocks = []
    @players = {}

    nonBlockingIds = @tilePositions.nonBlockingIds

    @forEachTile (w, h) =>
      i = h * @width + w
      j = @tilePositions.tileKeys[i]
      mapObj = x: w * @cellSize, y: h * @cellSize
      mapObj.blocker = true unless nonBlockingIds.indexOf(j) != -1
      @blocks.push mapObj

    @tileMap = new TileMap size: [@width, @height], cell_size: [@cellSize, @cellSize]
    @tileMap.push(@blocks)

  forEachTile: (cb) ->
    y = 0
    while y < @height
      x = 0
      while x < @width
        cb(x,y)
        x++
      y++

  atRect: (player) ->
    playerRect = x: player.x, y: player.y, width: 18, height: 18
    @tileMap.atRect playerRect

  getRandomSpawnCoordinates: ->
    nonBlockerCoords = @unoccupiedCoordinates()
    randInt = Math.floor(Math.random() * nonBlockerCoords.length)
    nonBlockerCoords[randInt]

  unoccupiedCoordinates: ->
    out = []
    @forEachTile (tileX,tileY) =>
      mapObjs = @tileMap.atRect @tileRectAt(tileX, tileY)
      playerMapObjs = @atRect(player) for player in @players
      mapObjs = _.without mapObjs, playerMapObjs
      unless _(mapObjs).any((s) -> s.blocker)
        out.push x: tileX * @cellSize, y: tileY * @cellSize
    out

  tileRectAt: (tileX, tileY) ->
    x = tileX * @cellSize
    y = tileY * @cellSize

    x: x
    right: x + @cellSize - 1
    width: @cellSize - 1
    y: y
    bottom: y + @cellSize - 1
    height: @cellSize - 1

  needMoreGuards: ->
    guards = _.filter @players, (player) -> player.isGuard
    thieves = _.filter @players, (player) -> !player.isGuard

    guards.length < thieves.length


