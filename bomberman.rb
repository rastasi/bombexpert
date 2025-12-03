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

# player
$playerX = 16
$playerY = 16

# game objects
$bombs = []
$explosions = []

# enemy
$enemy = {
  x: 208,
  y: 112,
  dir: 0,
  moveTimer: 0
}

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

  # handle input
  newX = $playerX
  newY = $playerY

  newY = $playerY - 1 if btn(0)
  newY = $playerY + 1 if btn(1)
  newX = $playerX - 1 if btn(2)
  newX = $playerX + 1 if btn(3)

  $playerX = newX unless solid?(newX, $playerY)
  $playerY = newY unless solid?($playerX, newY)

  # place bomb
  if btnp(4)
    bombX = ($playerX / TILE_SIZE).floor * TILE_SIZE
    bombY = ($playerY / TILE_SIZE).floor * TILE_SIZE
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

  # draw player
  rect($playerX, $playerY, PLAYER_SIZE, PLAYER_SIZE, 12)

  # draw enemy
  rect($enemy[:x], $enemy[:y], PLAYER_SIZE, PLAYER_SIZE, 2)

  # check player death by explosion
  $explosions.each do |expl|
    if $playerX < expl[:x] + TILE_SIZE && $playerX + PLAYER_SIZE > expl[:x] &&
       $playerY < expl[:y] + TILE_SIZE && $playerY + PLAYER_SIZE > expl[:y]
      $playerX = 16
      $playerY = 16
    end
  end

  # check player death by enemy
  if $playerX < $enemy[:x] + PLAYER_SIZE && $playerX + PLAYER_SIZE > $enemy[:x] &&
     $playerY < $enemy[:y] + PLAYER_SIZE && $playerY + PLAYER_SIZE > $enemy[:y]
    $playerX = 16
    $playerY = 16
  end

  # check enemy death by explosion
  $explosions.each do |expl|
    if $enemy[:x] < expl[:x] + TILE_SIZE && $enemy[:x] + PLAYER_SIZE > expl[:x] &&
       $enemy[:y] < expl[:y] + TILE_SIZE && $enemy[:y] + PLAYER_SIZE > expl[:y]
      $enemy[:x] = 208
      $enemy[:y] = 112
    end
  end

  print("ARROWS:MOVE A:BOMB", 50, 2, 15)
end

def solid?(x, y)
  gridLeft = (x / TILE_SIZE).floor
  gridTop = (y / TILE_SIZE).floor
  gridRight = ((x + PLAYER_SIZE - 1) / TILE_SIZE).floor
  gridBottom = ((y + PLAYER_SIZE - 1) / TILE_SIZE).floor

  return true if gridLeft < 0 || gridTop < 0 || gridRight > 14 || gridBottom > 8
  return true if $map[gridTop][gridLeft] >= SOLID_WALL
  return true if $map[gridTop][gridRight] >= SOLID_WALL
  return true if $map[gridBottom][gridLeft] >= SOLID_WALL
  return true if $map[gridBottom][gridRight] >= SOLID_WALL
  false
end

def update_enemy
  $enemy[:moveTimer] += 1
  return if $enemy[:moveTimer] < 3
  $enemy[:moveTimer] = 0

  # try current direction
  dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]]
  dir = $enemy[:dir]
  dx = dirs[dir] ? dirs[dir][0] : 0
  dy = dirs[dir] ? dirs[dir][1] : 0

  newEnemyX = $enemy[:x] + dx
  newEnemyY = $enemy[:y] + dy

  if !solid_for_enemy?(newEnemyX, newEnemyY) && rand > 0.1
    $enemy[:x] = newEnemyX
    $enemy[:y] = newEnemyY
  else
    $enemy[:dir] = rand(4)
  end
end

def solid_for_enemy?(x, y)
  gridLeft = (x / TILE_SIZE).floor
  gridTop = (y / TILE_SIZE).floor
  gridRight = ((x + PLAYER_SIZE - 1) / TILE_SIZE).floor
  gridBottom = ((y + PLAYER_SIZE - 1) / TILE_SIZE).floor

  return true if gridLeft < 0 || gridTop < 0 || gridRight > 14 || gridBottom > 8
  return true if $map[gridTop][gridLeft] >= SOLID_WALL
  return true if $map[gridTop][gridRight] >= SOLID_WALL
  return true if $map[gridBottom][gridLeft] >= SOLID_WALL
  return true if $map[gridBottom][gridRight] >= SOLID_WALL
  false
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

