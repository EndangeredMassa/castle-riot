Direction = require '../../client/node_modules/player/directions'

module.exports = class Player
  constructor: ({ @id, @x, @y, @isGuard }) ->
    @id = parseInt(@id, 10)
    @direction = Direction.NONE
    @faceDirection = Direction.NONE

  orient: (direction) ->
    @direction = direction
    return unless direction
    @faceDirection = direction

  toJSON: ->
    { @id, @x, @y, @isGuard, @direction, @faceDirection }

  toHash: -> @toJSON()

