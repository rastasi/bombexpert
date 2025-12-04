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

# create a new player/enemy entity
def create_player(gridX, gridY, color, is_ai = false)
  {
    gridX: gridX,
    gridY: gridY,
    pixelX: gridX * TILE_SIZE,
    pixelY: gridY * TILE_SIZE,
    moving: false,
    maxBombs: 1,
    activeBombs: 0,
    color: color,
    is_ai: is_ai,
    moveTimer: 0,
    bombCooldown: 0,
    spawnX: gridX,
    spawnY: gridY
  }
end

# players array (first is human, rest are AI)
$players = []
$players << create_player(1, 1, 12, false)   # human player (blue)
$players << create_player(13, 7, 2, true)    # AI enemy (red)

# powerups (extra bombs hidden under breakable walls)
$powerups = []

# game objects
$bombs = []
$explosions = []

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

def init_powerups
  $powerups = []
  # find all breakable walls and randomly place powerups under some
  (0..8).each do |row|
    (0..14).each do |col|
      if $map[row][col] == BREAKABLE_WALL && rand < 0.3
        $powerups << { gridX: col, gridY: row, type: :bomb }
      end
    end
  end
end

init_powerups

def TIC
  cls(0)

  # update all players
  $players.each do |player|
    update_player_movement(player)

    if player[:is_ai]
      update_ai(player)
    else
      handle_human_input(player)
    end
  end

  # update bombs
  $bombs.reverse_each do |bomb|
    bomb[:timer] -= 1
    if bomb[:timer] <= 0
      explode(bomb[:x], bomb[:y])
      $bombs.delete(bomb)
      bomb[:owner][:activeBombs] -= 1 if bomb[:owner]
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

  # draw powerups (only visible when wall is destroyed)
  $powerups.each do |pw|
    if $map[pw[:gridY]][pw[:gridX]] == EMPTY
      drawX = pw[:gridX] * TILE_SIZE
      drawY = pw[:gridY] * TILE_SIZE
      rect(drawX + 3, drawY + 3, 10, 10, 6)
      print("B", drawX + 5, drawY + 5, 0)
    end
  end

  # check powerup pickup for all players
  $players.each do |player|
    $powerups.reverse_each do |pw|
      if $map[pw[:gridY]][pw[:gridX]] == EMPTY &&
         player[:gridX] == pw[:gridX] && player[:gridY] == pw[:gridY]
        player[:maxBombs] += 1
        $powerups.delete(pw)
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

  # draw all players
  $players.each do |player|
    rect(player[:pixelX] + 2, player[:pixelY] + 2, PLAYER_SIZE, PLAYER_SIZE, player[:color])
  end

  # check death by explosion for all players
  $players.each do |player|
    $explosions.each do |expl|
      explGridX = (expl[:x] / TILE_SIZE).floor
      explGridY = (expl[:y] / TILE_SIZE).floor
      if player[:gridX] == explGridX && player[:gridY] == explGridY
        reset_player_entity(player)
      end
    end
  end

  # check human player death by touching AI enemy
  human = $players[0]
  $players.each do |player|
    if player[:is_ai] && human[:gridX] == player[:gridX] && human[:gridY] == player[:gridY]
      reset_player_entity(human)
    end
  end

  print("ARROWS:MOVE A:BOMB", 50, 2, 15)
  human = $players[0]
  available = human[:maxBombs] - human[:activeBombs]
  print("BOMBS:#{available}/#{human[:maxBombs]}", 170, 2, 11)
end

# common movement animation for all players
def update_player_movement(player)
  targetX = player[:gridX] * TILE_SIZE
  targetY = player[:gridY] * TILE_SIZE

  if player[:pixelX] < targetX
    player[:pixelX] = [player[:pixelX] + MOVE_SPEED, targetX].min
    player[:moving] = true
  elsif player[:pixelX] > targetX
    player[:pixelX] = [player[:pixelX] - MOVE_SPEED, targetX].max
    player[:moving] = true
  elsif player[:pixelY] < targetY
    player[:pixelY] = [player[:pixelY] + MOVE_SPEED, targetY].min
    player[:moving] = true
  elsif player[:pixelY] > targetY
    player[:pixelY] = [player[:pixelY] - MOVE_SPEED, targetY].max
    player[:moving] = true
  else
    player[:moving] = false
  end

  player[:bombCooldown] -= 1 if player[:bombCooldown] > 0
end

# handle human player input
def handle_human_input(player)
  return if player[:moving]

  newGridX = player[:gridX]
  newGridY = player[:gridY]

  if btn(0)
    newGridY = player[:gridY] - 1
  elsif btn(1)
    newGridY = player[:gridY] + 1
  elsif btn(2)
    newGridX = player[:gridX] - 1
  elsif btn(3)
    newGridX = player[:gridX] + 1
  end

  if can_move_to?(newGridX, newGridY)
    player[:gridX] = newGridX
    player[:gridY] = newGridY
  end

  # place bomb
  if btnp(4)
    place_bomb(player)
  end
end

# AI player logic
def update_ai(player)
  return if player[:moving]

  player[:moveTimer] += 1
  return if player[:moveTimer] < 20

  player[:moveTimer] = 0

  # check if in danger
  danger_dir = get_escape_direction(player[:gridX], player[:gridY])

  if danger_dir
    newGridX = player[:gridX] + danger_dir[0]
    newGridY = player[:gridY] + danger_dir[1]
    if can_move_to?(newGridX, newGridY) && !is_dangerous?(newGridX, newGridY)
      player[:gridX] = newGridX
      player[:gridY] = newGridY
    else
      try_escape_any_direction(player)
    end
  else
    ai_move_and_bomb(player)
  end
end

# check if a position is dangerous (bomb blast zone or explosion)
def is_dangerous?(gridX, gridY)
  # check explosions
  $explosions.each do |expl|
    explGridX = (expl[:x] / TILE_SIZE).floor
    explGridY = (expl[:y] / TILE_SIZE).floor
    return true if gridX == explGridX && gridY == explGridY
  end

  # check bombs and their blast zones
  $bombs.each do |bomb|
    bombGridX = (bomb[:x] / TILE_SIZE).floor
    bombGridY = (bomb[:y] / TILE_SIZE).floor

    # bomb position
    return true if gridX == bombGridX && gridY == bombGridY

    # horizontal blast zone
    if gridY == bombGridY
      if (gridX - bombGridX).abs <= 1
        # check if wall blocks the blast
        if gridX < bombGridX
          return true if $map[gridY][gridX + 1] != SOLID_WALL
        elsif gridX > bombGridX
          return true if $map[gridY][gridX - 1] != SOLID_WALL
        end
      end
    end

    # vertical blast zone
    if gridX == bombGridX
      if (gridY - bombGridY).abs <= 1
        # check if wall blocks the blast
        if gridY < bombGridY
          return true if $map[gridY + 1][gridX] != SOLID_WALL
        elsif gridY > bombGridY
          return true if $map[gridY - 1][gridX] != SOLID_WALL
        end
      end
    end
  end

  false
end

# find escape direction away from danger
def get_escape_direction(gridX, gridY)
  return nil unless is_dangerous?(gridX, gridY)

  # find direction away from nearest bomb
  $bombs.each do |bomb|
    bombGridX = (bomb[:x] / TILE_SIZE).floor
    bombGridY = (bomb[:y] / TILE_SIZE).floor

    # if on same row as bomb, move vertically
    if gridY == bombGridY && (gridX - bombGridX).abs <= 1
      return [0, -1] if can_move_to?(gridX, gridY - 1) && !is_dangerous?(gridX, gridY - 1)
      return [0, 1] if can_move_to?(gridX, gridY + 1) && !is_dangerous?(gridX, gridY + 1)
    end

    # if on same column as bomb, move horizontally
    if gridX == bombGridX && (gridY - bombGridY).abs <= 1
      return [-1, 0] if can_move_to?(gridX - 1, gridY) && !is_dangerous?(gridX - 1, gridY)
      return [1, 0] if can_move_to?(gridX + 1, gridY) && !is_dangerous?(gridX + 1, gridY)
    end
  end

  nil
end

# try to escape in any safe direction
def try_escape_any_direction(player)
  dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]].shuffle
  dirs.each do |dir|
    newX = player[:gridX] + dir[0]
    newY = player[:gridY] + dir[1]
    if can_move_to?(newX, newY) && !is_dangerous?(newX, newY)
      player[:gridX] = newX
      player[:gridY] = newY
      return
    end
  end
end

# escape immediately after placing bomb
def escape_from_own_bomb(player)
  dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]].shuffle
  dirs.each do |dir|
    newX = player[:gridX] + dir[0]
    newY = player[:gridY] + dir[1]
    if can_move_to?(newX, newY)
      player[:gridX] = newX
      player[:gridY] = newY
      return
    end
  end
end

# check if there's a breakable wall adjacent to position
def has_adjacent_breakable_wall?(gridX, gridY)
  dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]]
  dirs.each do |dir|
    checkX = gridX + dir[0]
    checkY = gridY + dir[1]
    if checkX >= 0 && checkX <= 14 && checkY >= 0 && checkY <= 8
      return true if $map[checkY][checkX] == BREAKABLE_WALL
    end
  end
  false
end

# check if enemy has a safe escape route after placing bomb
def has_escape_route?(gridX, gridY)
  dirs = [[0, -1], [0, 1], [-1, 0], [1, 0]]
  dirs.each do |dir|
    newX = gridX + dir[0]
    newY = gridY + dir[1]
    # check if can move there and it's not in bomb blast zone
    if can_move_to?(newX, newY)
      # check one more step for safety
      dirs.each do |dir2|
        safeX = newX + dir2[0]
        safeY = newY + dir2[1]
        if can_move_to?(safeX, safeY)
          return true
        end
      end
    end
  end
  false
end

# place bomb for any player
def place_bomb(player)
  return if player[:activeBombs] >= player[:maxBombs]

  bombX = player[:gridX] * TILE_SIZE
  bombY = player[:gridY] * TILE_SIZE
  already_bomb = $bombs.any? { |b| b[:x] == bombX && b[:y] == bombY }

  unless already_bomb
    $bombs << { x: bombX, y: bombY, timer: BOMB_TIMER, owner: player }
    player[:activeBombs] += 1
  end
end

# AI movement and bombing logic
def ai_move_and_bomb(player)
  # find nearest human player to chase
  human = $players.find { |p| !p[:is_ai] }
  return unless human

  dx = human[:gridX] - player[:gridX]
  dy = human[:gridY] - player[:gridY]
  dist = dx.abs + dy.abs

  # decide if should place bomb
  should_bomb = false
  should_bomb = true if dist <= 2
  should_bomb = true if has_adjacent_breakable_wall?(player[:gridX], player[:gridY])

  # place bomb if should and can
  if should_bomb && player[:activeBombs] < player[:maxBombs] && player[:bombCooldown] <= 0
    if has_escape_route?(player[:gridX], player[:gridY])
      place_bomb(player)
      player[:bombCooldown] = 90
      escape_from_own_bomb(player)
      return
    end
  end

  # move toward human player
  dirs = []

  if dx > 0
    dirs << [1, 0]
  elsif dx < 0
    dirs << [-1, 0]
  end

  if dy > 0
    dirs << [0, 1]
  elsif dy < 0
    dirs << [0, -1]
  end

  dirs += [[0, -1], [0, 1], [-1, 0], [1, 0]].shuffle

  dirs.each do |dir|
    newGridX = player[:gridX] + dir[0]
    newGridY = player[:gridY] + dir[1]
    if can_move_to?(newGridX, newGridY) && !is_dangerous?(newGridX, newGridY)
      player[:gridX] = newGridX
      player[:gridY] = newGridY
      return
    end
  end
end

def can_move_to?(gridX, gridY)
  return false if gridX < 0 || gridY < 0 || gridX > 14 || gridY > 8
  return false if $map[gridY][gridX] >= SOLID_WALL
  true
end

# reset any player to spawn position
def reset_player_entity(player)
  player[:gridX] = player[:spawnX]
  player[:gridY] = player[:spawnY]
  player[:pixelX] = player[:spawnX] * TILE_SIZE
  player[:pixelY] = player[:spawnY] * TILE_SIZE
  player[:moving] = false
  player[:maxBombs] = 1
  player[:activeBombs] = 0
  player[:bombCooldown] = 0
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

