# title:   game title
# author:  game developer, email, etc.
# desc:    short description
# site:    website link
# license: MIT License (change this to your license of choice)
# version: 0.1
# script:  ruby

# constants
TILE_SIZE = 16
PLAYER_SIZE = 12
BOMB_TIMER = 90
EXPLOSION_TIMER = 30

EMPTY = 0
SOLID_WALL = 1
BREAKABLE_WALL = 2

# player (grid position and pixel position for animation)
$player = {
  gridX: 1,
  gridY: 1,
  pixelX: 16,
  pixelY: 16,
  moving: false
}

# game objects
$bombs = []
$explosions = []

# enemy (grid position and pixel position for animation)
$enemy = {
  gridX: 13,
  gridY: 7,
  pixelX: 208,
  pixelY: 112,
  moving: false,
  moveTimer: 0
}

# animation speed (pixels per frame)
MOVE_SPEED = 2

# 1=solid wall, 2=breakable wall
$map = [
  [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
  [1,0,0,2,2,2,0,2,0,2,2,2,0,0,1],
  [1,0,1,2,1,2,1,2,1,2,1,2,1,0,1],
  [1,2,2,2,0,2,2,0,2,2,0,2,2,2,1],
  [1,2,1,0,1,0,1,0,1,0,1,0,1,2,1],
  [1,2,2,2,0,2,2,0,2,2,0,2,2,2,1],
  [1,0,1,2,1,2,1,2,1,2,1,2,1,0,1],
  [1,0,0,2,2,2,0,2,0,2,2,2,0,0,1],
  [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
]

def TIC
  cls(0)

  # handle player movement
  update_player

  # place bomb
  if btnp(4)
    bombX = $player[:gridX] * TILE_SIZE
    bombY = $player[:gridY] * TILE_SIZE
    $bombs << { x: bombX, y: bombY, timer: BOMB_TIMER }
  end

  # update bombs
  $bombs.reverse_each do |bomb|
    bomb[:timer] -= 1
    if bomb[:timer] <= 0
      explode(bomb[:x], bomb[:y])
      $bombs.delete(bomb)
    end
  end

  # update explosions
  $explosions.reverse_each do |expl|
    expl[:timer] -= 1
    $explosions.delete(expl) if expl[:timer] <= 0
  end

  # draw map
  (0..8).each do |row|
    (0..14).each do |col|
      tile = $map[row][col]
      drawX = col * TILE_SIZE
      drawY = row * TILE_SIZE
      if tile == SOLID_WALL
        rect(drawX, drawY, TILE_SIZE, TILE_SIZE, 8)
      elsif tile == BREAKABLE_WALL
        rect(drawX, drawY, TILE_SIZE, TILE_SIZE, 4)
      end
    end
  end

  # draw bombs
  $bombs.each do |bomb|
    circ(bomb[:x] + 8, bomb[:y] + 8, 6, 2)
  end

  # draw explosions
  $explosions.each do |expl|
    rect(expl[:x], expl[:y], TILE_SIZE, TILE_SIZE, 6)
  end

  # update enemy
  update_enemy

  # draw player (centered in tile)
  rect($player[:pixelX] + 2, $player[:pixelY] + 2, PLAYER_SIZE, PLAYER_SIZE, 12)

  # draw enemy (centered in tile)
  rect($enemy[:pixelX] + 2, $enemy[:pixelY] + 2, PLAYER_SIZE, PLAYER_SIZE, 2)

  # check player death by explosion (grid-based)
  $explosions.each do |expl|
    explGridX = (expl[:x] / TILE_SIZE).floor
    explGridY = (expl[:y] / TILE_SIZE).floor
    if $player[:gridX] == explGridX && $player[:gridY] == explGridY
      reset_player
    end
  end

  # check player death by enemy (grid-based)
  if $player[:gridX] == $enemy[:gridX] && $player[:gridY] == $enemy[:gridY]
    reset_player
  end

  # check enemy death by explosion (grid-based)
  $explosions.each do |expl|
    explGridX = (expl[:x] / TILE_SIZE).floor
    explGridY = (expl[:y] / TILE_SIZE).floor
    if $enemy[:gridX] == explGridX && $enemy[:gridY] == explGridY
      reset_enemy
    end
  end

  print("ARROWS:MOVE A:BOMB", 50, 2, 15)
end

def update_player
  targetX = $player[:gridX] * TILE_SIZE
  targetY = $player[:gridY] * TILE_SIZE

  # animate toward target position
  if $player[:pixelX] < targetX
    $player[:pixelX] = [$player[:pixelX] + MOVE_SPEED, targetX].min
    $player[:moving] = true
  elsif $player[:pixelX] > targetX
    $player[:pixelX] = [$player[:pixelX] - MOVE_SPEED, targetX].max
    $player[:moving] = true
  elsif $player[:pixelY] < targetY
    $player[:pixelY] = [$player[:pixelY] + MOVE_SPEED, targetY].min
    $player[:moving] = true
  elsif $player[:pixelY] > targetY
    $player[:pixelY] = [$player[:pixelY] - MOVE_SPEED, targetY].max
    $player[:moving] = true
  else
    $player[:moving] = false
  end

  # only accept input when not moving
  return if $player[:moving]

  newGridX = $player[:gridX]
  newGridY = $player[:gridY]

  if btn(0)
    newGridY = $player[:gridY] - 1
  elsif btn(1)
    newGridY = $player[:gridY] + 1
  elsif btn(2)
    newGridX = $player[:gridX] - 1
  elsif btn(3)
    newGridX = $player[:gridX] + 1
  end

  # check if new grid position is valid
  if can_move_to?(newGridX, newGridY)
    $player[:gridX] = newGridX
    $player[:gridY] = newGridY
  end
end

def update_enemy
  targetX = $enemy[:gridX] * TILE_SIZE
  targetY = $enemy[:gridY] * TILE_SIZE

  # animate toward target position
  if $enemy[:pixelX] < targetX
    $enemy[:pixelX] = [$enemy[:pixelX] + MOVE_SPEED, targetX].min
    $enemy[:moving] = true
  elsif $enemy[:pixelX] > targetX
    $enemy[:pixelX] = [$enemy[:pixelX] - MOVE_SPEED, targetX].max
    $enemy[:moving] = true
  elsif $enemy[:pixelY] < targetY
    $enemy[:pixelY] = [$enemy[:pixelY] + MOVE_SPEED, targetY].min
    $enemy[:moving] = true
  elsif $enemy[:pixelY] > targetY
    $enemy[:pixelY] = [$enemy[:pixelY] - MOVE_SPEED, targetY].max
    $enemy[:moving] = true
  else
    $enemy[:moving] = false
  end

  # only move when animation is complete
  return if $enemy[:moving]

  $enemy[:moveTimer] += 1
  return if $enemy[:moveTimer] < 30

  $enemy[:moveTimer] = 0

  # pick random direction
  dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]]
  dir = rand(4)
  newGridX = $enemy[:gridX] + dirs[dir][0]
  newGridY = $enemy[:gridY] + dirs[dir][1]

  if can_move_to?(newGridX, newGridY)
    $enemy[:gridX] = newGridX
    $enemy[:gridY] = newGridY
  end
end

def can_move_to?(gridX, gridY)
  return false if gridX < 0 || gridY < 0 || gridX > 14 || gridY > 8
  return false if $map[gridY][gridX] >= SOLID_WALL
  true
end

def reset_player
  $player[:gridX] = 1
  $player[:gridY] = 1
  $player[:pixelX] = 16
  $player[:pixelY] = 16
  $player[:moving] = false
end

def reset_enemy
  $enemy[:gridX] = 13
  $enemy[:gridY] = 7
  $enemy[:pixelX] = 208
  $enemy[:pixelY] = 112
  $enemy[:moving] = false
end

def explode(bombX, bombY)
  $explosions << { x: bombX, y: bombY, timer: EXPLOSION_TIMER }

  # horizontal explosion
  [-1, 1].each do |dir|
    explX = bombX + dir * TILE_SIZE
    gridX = (explX / TILE_SIZE).floor
    gridY = (bombY / TILE_SIZE).floor
    if gridX >= 0 && gridX <= 14
      tile = $map[gridY][gridX]
      if tile == EMPTY
        $explosions << { x: explX, y: bombY, timer: EXPLOSION_TIMER }
      elsif tile == BREAKABLE_WALL
        $map[gridY][gridX] = EMPTY
        $explosions << { x: explX, y: bombY, timer: EXPLOSION_TIMER }
      end
    end
  end

  # vertical explosion
  [-1, 1].each do |dir|
    explY = bombY + dir * TILE_SIZE
    gridX = (bombX / TILE_SIZE).floor
    gridY = (explY / TILE_SIZE).floor
    if gridY >= 0 && gridY <= 8
      tile = $map[gridY][gridX]
      if tile == EMPTY
        $explosions << { x: bombX, y: explY, timer: EXPLOSION_TIMER }
      elsif tile == BREAKABLE_WALL
        $map[gridY][gridX] = EMPTY
        $explosions << { x: bombX, y: explY, timer: EXPLOSION_TIMER }
      end
    end
  end
end


# <TILES>
# 001:eccccccccc888888caaaaaaaca888888cacccccccacc0ccccacc0ccccacc0ccc
# 002:ccccceee8888cceeaaaa0cee888a0ceeccca0ccc0cca0c0c0cca0c0c0cca0c0c
# 003:eccccccccc888888caaaaaaaca888888cacccccccacccccccacc0ccccacc0ccc
# 004:ccccceee8888cceeaaaa0cee888a0ceeccca0cccccca0c0c0cca0c0c0cca0c0c
# 017:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
# 018:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
# 019:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
# 020:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
# </TILES>

# <WAVES>
# 000:00000000ffffffff00000000ffffffff
# 001:0123456789abcdeffedcba9876543210
# 002:0123456789abcdef0123456789abcdef
# </WAVES>

# <SFX>
# 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
# </SFX>

# <TRACKS>
# 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
# </TRACKS>

# <PALETTE>
# 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
# </PALETTE>

