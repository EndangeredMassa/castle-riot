module.exports = class Position
  constructor: ({ @id, @x, @y }) ->
    @origX = @x
    @origY = @y
