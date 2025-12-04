-- title:   Bomberman Clone
-- author:  Zsolt Tasnadi
-- desc:    Simple Bomberman clone for TIC-80
-- site:    http://teletype.hu
-- license: MIT License
-- version: 0.1
-- script:  lua

-- constants
local TILE_SIZE = 16
local PLAYER_SIZE = 12
local BOMB_TIMER = 90
local EXPLOSION_TIMER = 30

local EMPTY = 0
local SOLID_WALL = 1
local BREAKABLE_WALL = 2

local MOVE_SPEED = 2

-- sprite indices (in SPRITES section, starts at 256)
local ASTRONAUT_BLUE = 256
local ASTRONAUT_RED = 257
local BOMB_SPRITE = 258
local BREAKABLE_WALL_SPRITE = 259
local SOLID_WALL_SPRITE = 260

-- game state constants
local GAME_STATE_SPLASH = 0
local GAME_STATE_MENU = 1
local GAME_STATE_PLAYING = 2

-- game state variables
local game_state = GAME_STATE_SPLASH
local splash_timer = 90  -- 1.5 seconds at 60fps
local menu_selection = 1  -- 1 = Play, 2 = Exit

local players = {}
local powerups = {}
local bombs = {}
local explosions = {}
local winner = nil
local win_timer = 0
local score = {0, 0}

-- map (1=solid wall, 2=breakable wall)
local map = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,2,2,2,0,2,0,2,2,2,0,0,1},
  {1,0,1,2,1,2,1,2,1,2,1,2,1,0,1},
  {1,2,2,2,0,2,2,0,2,2,0,2,2,2,1},
  {1,2,1,0,1,0,1,0,1,0,1,0,1,2,1},
  {1,2,2,2,0,2,2,0,2,2,0,2,2,2,1},
  {1,0,1,2,1,2,1,2,1,2,1,2,1,0,1},
  {1,0,0,2,2,2,0,2,0,2,2,2,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

-- initial map for reset
local initial_map = {
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  {1,0,0,2,2,2,0,2,0,2,2,2,0,0,1},
  {1,0,1,2,1,2,1,2,1,2,1,2,1,0,1},
  {1,2,2,2,0,2,2,0,2,2,0,2,2,2,1},
  {1,2,1,0,1,0,1,0,1,0,1,0,1,2,1},
  {1,2,2,2,0,2,2,0,2,2,0,2,2,2,1},
  {1,0,1,2,1,2,1,2,1,2,1,2,1,0,1},
  {1,0,0,2,2,2,0,2,0,2,2,2,0,0,1},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}
}

local function create_player(gridX, gridY, color, is_ai)
  return {
    gridX = gridX,
    gridY = gridY,
    pixelX = (gridX - 1) * TILE_SIZE,
    pixelY = (gridY - 1) * TILE_SIZE,
    moving = false,
    maxBombs = 1,
    activeBombs = 0,
    color = color,
    is_ai = is_ai,
    moveTimer = 0,
    bombCooldown = 0,
    spawnX = gridX,
    spawnY = gridY
  }
end

local function init_powerups()
  powerups = {}
  for row = 1, 9 do
    for col = 1, 15 do
      if map[row][col] == BREAKABLE_WALL and math.random() < 0.3 then
        table.insert(powerups, {gridX = col, gridY = row, type = "bomb"})
      end
    end
  end
end

local function init_game()
  players = {}
  table.insert(players, create_player(2, 2, 12, false))  -- human player (blue)
  table.insert(players, create_player(14, 8, 2, true))   -- AI enemy (red)
  init_powerups()
end

local function can_move_to(gridX, gridY)
  if gridX < 1 or gridY < 1 or gridX > 15 or gridY > 9 then
    return false
  end
  if map[gridY][gridX] >= SOLID_WALL then
    return false
  end
  return true
end

local function is_dangerous(gridX, gridY)
  for _, expl in ipairs(explosions) do
    local explGridX = math.floor(expl.x / TILE_SIZE) + 1
    local explGridY = math.floor(expl.y / TILE_SIZE) + 1
    if gridX == explGridX and gridY == explGridY then
      return true
    end
  end

  for _, bomb in ipairs(bombs) do
    local bombGridX = math.floor(bomb.x / TILE_SIZE) + 1
    local bombGridY = math.floor(bomb.y / TILE_SIZE) + 1

    if gridX == bombGridX and gridY == bombGridY then
      return true
    end

    if gridY == bombGridY then
      if math.abs(gridX - bombGridX) <= 1 then
        if gridX < bombGridX then
          if map[gridY][gridX + 1] ~= SOLID_WALL then return true end
        elseif gridX > bombGridX then
          if map[gridY][gridX - 1] ~= SOLID_WALL then return true end
        end
      end
    end

    if gridX == bombGridX then
      if math.abs(gridY - bombGridY) <= 1 then
        if gridY < bombGridY then
          if map[gridY + 1][gridX] ~= SOLID_WALL then return true end
        elseif gridY > bombGridY then
          if map[gridY - 1][gridX] ~= SOLID_WALL then return true end
        end
      end
    end
  end

  return false
end

local function in_blast_zone(gridX, gridY, bombGridX, bombGridY)
  if gridX == bombGridX and gridY == bombGridY then
    return true
  end

  if gridY == bombGridY and math.abs(gridX - bombGridX) <= 1 then
    if gridX < bombGridX then
      return map[gridY][gridX + 1] ~= SOLID_WALL
    elseif gridX > bombGridX then
      return map[gridY][gridX - 1] ~= SOLID_WALL
    end
  end

  if gridX == bombGridX and math.abs(gridY - bombGridY) <= 1 then
    if gridY < bombGridY then
      return map[gridY + 1][gridX] ~= SOLID_WALL
    elseif gridY > bombGridY then
      return map[gridY - 1][gridX] ~= SOLID_WALL
    end
  end

  return false
end

local function has_adjacent_breakable_wall(gridX, gridY)
  local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
  for _, dir in ipairs(dirs) do
    local checkX = gridX + dir[1]
    local checkY = gridY + dir[2]
    if checkX >= 1 and checkX <= 15 and checkY >= 1 and checkY <= 9 then
      if map[checkY][checkX] == BREAKABLE_WALL then
        return true
      end
    end
  end
  return false
end

local function has_escape_route(gridX, gridY)
  local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
  for _, dir in ipairs(dirs) do
    local newX = gridX + dir[1]
    local newY = gridY + dir[2]
    if can_move_to(newX, newY) and not is_dangerous(newX, newY) then
      for _, dir2 in ipairs(dirs) do
        local safeX = newX + dir2[1]
        local safeY = newY + dir2[2]
        if can_move_to(safeX, safeY) then
          return true
        end
      end
    end
  end
  return false
end

local function place_bomb(player)
  if player.activeBombs >= player.maxBombs then return end

  local bombX = (player.gridX - 1) * TILE_SIZE
  local bombY = (player.gridY - 1) * TILE_SIZE

  for _, b in ipairs(bombs) do
    if b.x == bombX and b.y == bombY then
      return
    end
  end

  table.insert(bombs, {x = bombX, y = bombY, timer = BOMB_TIMER, owner = player})
  player.activeBombs = player.activeBombs + 1
end

local function escape_from_own_bomb(player)
  local bombGridX = player.gridX
  local bombGridY = player.gridY
  local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}

  local best_dir = nil
  local best_score = -999

  for _, dir in ipairs(dirs) do
    local newX = player.gridX + dir[1]
    local newY = player.gridY + dir[2]

    if can_move_to(newX, newY) then
      local sc = 0

      if not in_blast_zone(newX, newY, bombGridX, bombGridY) then
        sc = sc + 100
      end

      for _, dir2 in ipairs(dirs) do
        local checkX = newX + dir2[1]
        local checkY = newY + dir2[2]
        if not (checkX == bombGridX and checkY == bombGridY) then
          if can_move_to(checkX, checkY) then
            sc = sc + 10
            if not in_blast_zone(checkX, checkY, bombGridX, bombGridY) then
              sc = sc + 20
            end
          end
        end
      end

      if sc > best_score then
        best_score = sc
        best_dir = dir
      end
    end
  end

  if best_dir then
    player.gridX = player.gridX + best_dir[1]
    player.gridY = player.gridY + best_dir[2]
  end
end

local function ai_move_and_bomb(player)
  local human = players[1]
  if not human then return end

  local dx = human.gridX - player.gridX
  local dy = human.gridY - player.gridY
  local dist = math.abs(dx) + math.abs(dy)

  local should_bomb = false
  if dist <= 2 then should_bomb = true end
  if has_adjacent_breakable_wall(player.gridX, player.gridY) then
    should_bomb = true
  end

  if should_bomb and player.activeBombs < player.maxBombs and player.bombCooldown <= 0 then
    if has_escape_route(player.gridX, player.gridY) then
      place_bomb(player)
      player.bombCooldown = 90
      escape_from_own_bomb(player)
      return
    end
  end

  local dirs = {}
  if dx > 0 then table.insert(dirs, {1, 0})
  elseif dx < 0 then table.insert(dirs, {-1, 0})
  end
  if dy > 0 then table.insert(dirs, {0, 1})
  elseif dy < 0 then table.insert(dirs, {0, -1})
  end

  local all_dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
  for _, d in ipairs(all_dirs) do
    table.insert(dirs, d)
  end

  for _, dir in ipairs(dirs) do
    local newGridX = player.gridX + dir[1]
    local newGridY = player.gridY + dir[2]
    if can_move_to(newGridX, newGridY) and not is_dangerous(newGridX, newGridY) then
      player.gridX = newGridX
      player.gridY = newGridY
      return
    end
  end
end

local function update_player_movement(player)
  local targetX = (player.gridX - 1) * TILE_SIZE
  local targetY = (player.gridY - 1) * TILE_SIZE

  if player.pixelX < targetX then
    player.pixelX = math.min(player.pixelX + MOVE_SPEED, targetX)
    player.moving = true
  elseif player.pixelX > targetX then
    player.pixelX = math.max(player.pixelX - MOVE_SPEED, targetX)
    player.moving = true
  elseif player.pixelY < targetY then
    player.pixelY = math.min(player.pixelY + MOVE_SPEED, targetY)
    player.moving = true
  elseif player.pixelY > targetY then
    player.pixelY = math.max(player.pixelY - MOVE_SPEED, targetY)
    player.moving = true
  else
    player.moving = false
  end

  if player.bombCooldown > 0 then
    player.bombCooldown = player.bombCooldown - 1
  end
end

local function handle_human_input(player)
  if player.moving then return end

  local newGridX = player.gridX
  local newGridY = player.gridY

  if btn(0) then
    newGridY = player.gridY - 1
  elseif btn(1) then
    newGridY = player.gridY + 1
  elseif btn(2) then
    newGridX = player.gridX - 1
  elseif btn(3) then
    newGridX = player.gridX + 1
  end

  if can_move_to(newGridX, newGridY) then
    player.gridX = newGridX
    player.gridY = newGridY
  end

  if btnp(4) then
    place_bomb(player)
  end
end

local function update_ai(player)
  if player.moving then return end

  local in_danger = is_dangerous(player.gridX, player.gridY)

  if in_danger then
    local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
    local best_dir = nil
    local best_safe = false

    for _, dir in ipairs(dirs) do
      local newX = player.gridX + dir[1]
      local newY = player.gridY + dir[2]
      if can_move_to(newX, newY) then
        local safe = not is_dangerous(newX, newY)
        if safe and not best_safe then
          best_dir = dir
          best_safe = true
        elseif not best_dir then
          best_dir = dir
        end
      end
    end

    if best_dir then
      player.gridX = player.gridX + best_dir[1]
      player.gridY = player.gridY + best_dir[2]
    end
    player.moveTimer = 0
    return
  end

  player.moveTimer = player.moveTimer + 1
  if player.moveTimer < 20 then return end

  player.moveTimer = 0
  ai_move_and_bomb(player)
end

local function draw_player_sprite(x, y, is_player1)
  local sprite_id = is_player1 and ASTRONAUT_BLUE or ASTRONAUT_RED
  spr(sprite_id, x, y, 0, 2)
end

local function draw_bomb_sprite(x, y)
  spr(BOMB_SPRITE, x, y, 0, 2)
end

local function reset_player_entity(player)
  player.gridX = player.spawnX
  player.gridY = player.spawnY
  player.pixelX = (player.spawnX - 1) * TILE_SIZE
  player.pixelY = (player.spawnY - 1) * TILE_SIZE
  player.moving = false
  player.maxBombs = 1
  player.activeBombs = 0
  player.bombCooldown = 0
end

local function explode(bombX, bombY)
  table.insert(explosions, {x = bombX, y = bombY, timer = EXPLOSION_TIMER})

  local gridX = math.floor(bombX / TILE_SIZE) + 1
  local gridY = math.floor(bombY / TILE_SIZE) + 1

  -- horizontal explosion
  for _, dir in ipairs({-1, 1}) do
    local explX = bombX + dir * TILE_SIZE
    local eGridX = gridX + dir
    if eGridX >= 1 and eGridX <= 15 then
      local tile = map[gridY][eGridX]
      if tile == EMPTY then
        table.insert(explosions, {x = explX, y = bombY, timer = EXPLOSION_TIMER})
      elseif tile == BREAKABLE_WALL then
        map[gridY][eGridX] = EMPTY
        table.insert(explosions, {x = explX, y = bombY, timer = EXPLOSION_TIMER})
      end
    end
  end

  -- vertical explosion
  for _, dir in ipairs({-1, 1}) do
    local explY = bombY + dir * TILE_SIZE
    local eGridY = gridY + dir
    if eGridY >= 1 and eGridY <= 9 then
      local tile = map[eGridY][gridX]
      if tile == EMPTY then
        table.insert(explosions, {x = bombX, y = explY, timer = EXPLOSION_TIMER})
      elseif tile == BREAKABLE_WALL then
        map[eGridY][gridX] = EMPTY
        table.insert(explosions, {x = bombX, y = explY, timer = EXPLOSION_TIMER})
      end
    end
  end
end

local function set_winner(player_num)
  winner = player_num
  win_timer = 60
  score[player_num] = score[player_num] + 1
end

local function draw_win_screen()
  cls(0)
  rect(20, 30, 200, 80, 12)
  rect(22, 32, 196, 76, 0)
  print("PLAYER "..winner.." WON!", 70, 55, 12, false, 2)
  if win_timer <= 0 or math.floor(win_timer / 15) % 2 == 0 then
    print("Press A to restart", 70, 80, 12)
  end
end

local function restart_game()
  winner = nil
  win_timer = 0
  bombs = {}
  explosions = {}

  -- reset map from initial
  for row = 1, 9 do
    for col = 1, 15 do
      map[row][col] = initial_map[row][col]
    end
  end

  for _, p in ipairs(players) do
    reset_player_entity(p)
  end
  init_powerups()
end

local function draw_game()
  -- draw map
  for row = 1, 9 do
    for col = 1, 15 do
      local tile = map[row][col]
      local drawX = (col - 1) * TILE_SIZE
      local drawY = (row - 1) * TILE_SIZE
      if tile == SOLID_WALL then
        spr(SOLID_WALL_SPRITE, drawX, drawY, 0, 2)
      elseif tile == BREAKABLE_WALL then
        spr(BREAKABLE_WALL_SPRITE, drawX, drawY, 0, 2)
      end
    end
  end

  -- draw powerups
  for _, pw in ipairs(powerups) do
    if map[pw.gridY][pw.gridX] == EMPTY then
      local drawX = (pw.gridX - 1) * TILE_SIZE
      local drawY = (pw.gridY - 1) * TILE_SIZE
      rect(drawX + 3, drawY + 3, 10, 10, 6)
      print("B", drawX + 5, drawY + 5, 0)
    end
  end

  -- draw bombs
  for _, bomb in ipairs(bombs) do
    draw_bomb_sprite(bomb.x, bomb.y)
  end

  -- draw explosions
  for _, expl in ipairs(explosions) do
    rect(expl.x, expl.y, TILE_SIZE, TILE_SIZE, 6)
  end

  -- draw players
  for idx, player in ipairs(players) do
    draw_player_sprite(player.pixelX, player.pixelY, idx == 1)
  end

  -- score display
  print(score[1]..":"..score[2], 5, 2, 12)
  print("ARROWS:MOVE A:BOMB", 60, 2, 15)
  local human = players[1]
  local available = human.maxBombs - human.activeBombs
  print("BOMBS:"..available.."/"..human.maxBombs, 180, 2, 11)
end

local function update_splash()
  cls(0)

  -- title with line break
  print("Bomberman", 85, 50, 12, false, 2)
  print("Clone", 100, 70, 12, false, 2)

  splash_timer = splash_timer - 1
  if splash_timer <= 0 then
    game_state = GAME_STATE_MENU
  end
end

local function update_menu()
  cls(0)

  -- title
  print("Bomberman", 85, 30, 12, false, 2)
  print("Clone", 100, 50, 12, false, 2)

  -- menu options
  local play_color = (menu_selection == 1) and 11 or 15
  local exit_color = (menu_selection == 2) and 11 or 15

  -- selection indicator
  if menu_selection == 1 then
    print(">", 85, 90, 11)
  else
    print(">", 85, 110, 11)
  end

  print("Play", 95, 90, play_color)
  print("Exit", 95, 110, exit_color)

  -- handle input
  if btnp(0) then  -- up
    menu_selection = 1
  elseif btnp(1) then  -- down
    menu_selection = 2
  elseif btnp(4) then  -- A button (select)
    if menu_selection == 1 then
      game_state = GAME_STATE_PLAYING
      init_game()
    else
      exit()
    end
  end
end

function TIC()
  if game_state == GAME_STATE_SPLASH then
    update_splash()
    return
  elseif game_state == GAME_STATE_MENU then
    update_menu()
    return
  end

  -- GAME_STATE_PLAYING
  cls(6)  -- green background

  if winner then
    win_timer = win_timer - 1
    draw_win_screen()
    if btnp(4) and win_timer <= 0 then
      restart_game()
    end
    return
  end

  -- update all players
  for _, player in ipairs(players) do
    update_player_movement(player)
    if player.is_ai then
      update_ai(player)
    else
      handle_human_input(player)
    end
  end

  -- update bombs
  for i = #bombs, 1, -1 do
    local bomb = bombs[i]
    bomb.timer = bomb.timer - 1
    if bomb.timer <= 0 then
      explode(bomb.x, bomb.y)
      if bomb.owner then
        bomb.owner.activeBombs = bomb.owner.activeBombs - 1
      end
      table.remove(bombs, i)
    end
  end

  -- update explosions
  for i = #explosions, 1, -1 do
    local expl = explosions[i]
    expl.timer = expl.timer - 1
    if expl.timer <= 0 then
      table.remove(explosions, i)
    end
  end

  -- check powerup pickup
  for _, player in ipairs(players) do
    for i = #powerups, 1, -1 do
      local pw = powerups[i]
      if map[pw.gridY][pw.gridX] == EMPTY and
         player.gridX == pw.gridX and player.gridY == pw.gridY then
        player.maxBombs = player.maxBombs + 1
        table.remove(powerups, i)
      end
    end
  end

  -- check death by explosion
  for idx, player in ipairs(players) do
    for _, expl in ipairs(explosions) do
      local explGridX = math.floor(expl.x / TILE_SIZE) + 1
      local explGridY = math.floor(expl.y / TILE_SIZE) + 1
      if player.gridX == explGridX and player.gridY == explGridY then
        local winner_idx = (idx == 1) and 2 or 1
        set_winner(winner_idx)
        return
      end
    end
  end

  -- check human death by touching AI
  local human = players[1]
  for _, player in ipairs(players) do
    if player.is_ai and human.gridX == player.gridX and human.gridY == player.gridY then
      set_winner(2)
      return
    end
  end

  draw_game()
end

-- <TILES>
-- 001:eccccccccc888888caaaaaaaca888888cacccccccacc0ccccacc0ccccacc0ccc
-- 002:ccccceee8888cceeaaaa0cee888a0ceeccca0ccc0cca0c0c0cca0c0c0cca0c0c
-- 003:eccccccccc888888caaaaaaaca888888cacccccccacccccccacc0ccccacc0ccc
-- 004:ccccceee8888cceeaaaa0cee888a0ceeccca0cccccca0c0c0cca0c0c0cca0c0c
-- 017:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 018:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- 019:cacccccccaaaaaaacaaacaaacaaaaccccaaaaaaac8888888cc000cccecccccec
-- 020:ccca00ccaaaa0ccecaaa0ceeaaaa0ceeaaaa0cee8888ccee000cceeecccceeee
-- </TILES>

-- <WAVES>
-- 000:00000000ffffffff00000000ffffffff
-- 001:0123456789abcdeffedcba9876543210
-- 002:0123456789abcdef0123456789abcdef
-- </WAVES>

-- <SFX>
-- 000:000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000304000000000
-- </SFX>

-- <TRACKS>
-- 000:100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
-- </TRACKS>

-- <SPRITES>
-- 000:00cccc000c1cc1c00ccccccc00cccc000c0cc0c00c0cc0c00000000000000000
-- 001:00222200021221200222222200222200020220200202202000000000000000000
-- 002:00043000001111000111111001111110011111100011110000011000000000000
-- 003:ddd1ddddddd1dddd1111111ddddd1dddddddd1dd1111111ddd1ddddddd1ddddd
-- 004:8888888888888888888888888888888888888888888888888888888888888888
-- </SPRITES>

-- <PALETTE>
-- 000:1a1c2c5d275db13e53ef7d57ffcd75a7f07038b76425717929366f3b5dc941a6f673eff7f4f4f494b0c2566c86333c57
-- </PALETTE>
