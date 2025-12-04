-- title:   Bomberman Clone
-- author:  Zsolt Tasnadi
-- desc:    Simple Bomberman clone for TIC-80
-- site:    http://teletype.hu
-- license: MIT License
-- version: 0.2
-- script:  lua

-- luacheck: globals TIC btn btnp cls rect spr print exit sfx keyp key
-- luacheck: max line length 150

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

-- Tile constants
local TILE_SIZE = 8
local MAP_WIDTH = 27
local MAP_HEIGHT = 15
local BOARD_OFFSET_X = 12  -- (240-27*8)/2 = 12
local BOARD_OFFSET_Y = 14  -- top bar (10) + shadow (2) + gap (2)

-- Tile types
local EMPTY = 0
local SOLID_WALL = 1
local BREAKABLE_WALL = 2

-- Timing constants
local BOMB_TIMER = 90
local EXPLOSION_TIMER = 30
local SPREAD_DELAY = 6        -- ticks per cell spread
local SPLASH_DURATION = 90    -- 1.5 seconds at 60fps
local WIN_SCREEN_DURATION = 60
local AI_MOVE_DELAY = 20
local AI_BOMB_COOLDOWN = 90

-- Movement
local MOVE_SPEED = 2

-- Directions (up, down, left, right)
local DIRECTIONS = {
  {0, -1},
  {0, 1},
  {-1, 0},
  {1, 0}
}

-- Sprite indices (SPRITES section loads at 256+)
local PLAYER_BLUE = 256
local PLAYER_RED = 257
local BOMB_SPRITE = 258
local BREAKABLE_WALL_SPRITE = 259
local SOLID_WALL_SPRITE = 260

-- Colors (Sweetie 16 palette)
local COLOR_BLACK = 0
local COLOR_SHADOW = 1
local COLOR_RED = 2
local COLOR_ORANGE = 3
local COLOR_YELLOW = 4
local COLOR_GREEN = 6
local COLOR_BLUE = 9
local COLOR_BLUE_LIGHT = 10
local COLOR_CYAN = 11
local COLOR_LIGHT = 12      -- f4f4f4 - lightest color
local COLOR_GRAY_LIGHT = 13

-- Game states
local GAME_STATE_SPLASH = 0
local GAME_STATE_MENU = 1
local GAME_STATE_PLAYING = 2
local GAME_STATE_HELP = 3
local GAME_STATE_CREDITS = 4

-- Powerup spawn chance
local POWERUP_SPAWN_CHANCE = 0.3

--------------------------------------------------------------------------------
-- Modules
--------------------------------------------------------------------------------

local Input = {}
local Map = {}
local Powerup = {}
local UI = {}
local TopBar = {}
local Splash = {}
local Menu = {}
local Help = {}
local Credits = {}
local WinScreen = {}
local GameBoard = {}
local Bomb = {}
local AI = {}
local Player = {}
local Game = {}

--------------------------------------------------------------------------------
-- Game State
--------------------------------------------------------------------------------

local State = {
  game_state = GAME_STATE_SPLASH,
  splash_timer = SPLASH_DURATION,
  menu_selection = 1,
  two_player_mode = false,
  players = {},
  powerups = {},
  bombs = {},
  explosions = {},
  winner = nil,
  win_timer = 0,
  score = {0, 0},
  map = {}
}

-- Initialize empty map
for row = 1, MAP_HEIGHT do
  State.map[row] = {}
  for col = 1, MAP_WIDTH do
    State.map[row][col] = EMPTY
  end
end

--------------------------------------------------------------------------------
-- Powerup System (extensible)
--------------------------------------------------------------------------------

local POWERUP_TYPES = {
  {
    type = "bomb",
    weight = 50,
    color = COLOR_YELLOW,
    label = "B",
    apply = function(player) player.maxBombs = player.maxBombs + 1 end
  },
  {
    type = "power",
    weight = 50,
    color = COLOR_ORANGE,
    label = "P",
    apply = function(player) player.bombPower = player.bombPower + 1 end
  },
}

--------------------------------------------------------------------------------
-- Powerup module
--------------------------------------------------------------------------------

function Powerup.get_config(type_name)
  for _, p in ipairs(POWERUP_TYPES) do
    if p.type == type_name then
      return p
    end
  end
  return POWERUP_TYPES[1]
end

function Powerup.get_random_type()
  local total_weight = 0
  for _, p in ipairs(POWERUP_TYPES) do
    total_weight = total_weight + p.weight
  end
  local roll = math.random() * total_weight
  local cumulative = 0
  for _, p in ipairs(POWERUP_TYPES) do
    cumulative = cumulative + p.weight
    if roll <= cumulative then
      return p.type
    end
  end
  return POWERUP_TYPES[1].type
end

function Powerup.init()
  State.powerups = {}
  for row = 1, MAP_HEIGHT do
    for col = 1, MAP_WIDTH do
      if State.map[row][col] == BREAKABLE_WALL and math.random() < POWERUP_SPAWN_CHANCE then
        table.insert(State.powerups, {
          gridX = col,
          gridY = row,
          type = Powerup.get_random_type()
        })
      end
    end
  end
end

function Powerup.draw_all()
  for _, pw in ipairs(State.powerups) do
    if State.map[pw.gridY][pw.gridX] == EMPTY then
      local drawX = (pw.gridX - 1) * TILE_SIZE + BOARD_OFFSET_X
      local drawY = (pw.gridY - 1) * TILE_SIZE + BOARD_OFFSET_Y
      local config = Powerup.get_config(pw.type)
      rect(drawX + 2, drawY + 2, 5, 5, COLOR_SHADOW)
      rect(drawX + 1, drawY + 1, 5, 5, config.color)
      print(config.label, drawX + 2, drawY + 1, COLOR_BLACK)
    end
  end
end

function Powerup.check_pickup()
  for _, player in ipairs(State.players) do
    for i = #State.powerups, 1, -1 do
      local pw = State.powerups[i]
      if State.map[pw.gridY][pw.gridX] == EMPTY and
         player.gridX == pw.gridX and player.gridY == pw.gridY then
        local config = Powerup.get_config(pw.type)
        config.apply(player)
        table.remove(State.powerups, i)
        sfx(1, nil, 8)
      end
    end
  end
end

--------------------------------------------------------------------------------
-- Input module
--------------------------------------------------------------------------------

function Input.action_pressed()
  return btnp(4) or keyp(48)  -- A button or Space
end

function Input.up()
  return btn(0)
end

function Input.down()
  return btn(1)
end

function Input.left()
  return btn(2)
end

function Input.right()
  return btn(3)
end

function Input.up_pressed()
  return btnp(0)
end

function Input.down_pressed()
  return btnp(1)
end

-- Player 2 inputs (WASD + G for bomb)
function Input.p2_up()
  return key(23) or btn(8)  -- W key or gamepad 2 up
end

function Input.p2_down()
  return key(19) or btn(9)  -- S key or gamepad 2 down
end

function Input.p2_left()
  return key(1) or btn(10)  -- A key or gamepad 2 left
end

function Input.p2_right()
  return key(4) or btn(11)  -- D key or gamepad 2 right
end

function Input.p2_action()
  return keyp(7) or btnp(12)  -- G key or gamepad 2 A
end

--------------------------------------------------------------------------------
-- Map module
--------------------------------------------------------------------------------

function Map.can_move_to(gridX, gridY, player)
  if gridX < 1 or gridY < 1 or gridX > MAP_WIDTH or gridY > MAP_HEIGHT then
    return false
  end
  if State.map[gridY][gridX] >= SOLID_WALL then
    return false
  end
  -- Check for bombs (but allow staying on bomb you just placed)
  for _, bomb in ipairs(State.bombs) do
    local bombGridX = math.floor(bomb.x / TILE_SIZE) + 1
    local bombGridY = math.floor(bomb.y / TILE_SIZE) + 1
    if gridX == bombGridX and gridY == bombGridY then
      -- Allow if player is currently on the bomb (just placed it)
      if player and player.gridX == bombGridX and player.gridY == bombGridY then
        return true
      end
      return false
    end
  end
  return true
end

function Map.is_spawn_area(row, col)
  local lastCol = MAP_WIDTH - 1   -- 26 (for MAP_WIDTH=27)
  local lastRow = MAP_HEIGHT - 1  -- 14 (for MAP_HEIGHT=15)
  -- Top-left spawn (2,2) and adjacent
  if (row == 2 and col == 2) or (row == 2 and col == 3) or (row == 3 and col == 2) then
    return true
  end
  -- Top-right spawn and adjacent
  if (row == 2 and col == lastCol) or (row == 2 and col == lastCol - 1) or (row == 3 and col == lastCol) then
    return true
  end
  -- Bottom-left spawn and adjacent
  if (row == lastRow and col == 2) or (row == lastRow and col == 3) or (row == lastRow - 1 and col == 2) then
    return true
  end
  -- Bottom-right spawn and adjacent
  if (row == lastRow and col == lastCol) or (row == lastRow and col == lastCol - 1) or (row == lastRow - 1 and col == lastCol) then
    return true
  end
  return false
end

function Map.generate()
  for row = 1, MAP_HEIGHT do
    for col = 1, MAP_WIDTH do
      -- Border walls
      if row == 1 or row == MAP_HEIGHT or col == 1 or col == MAP_WIDTH then
        State.map[row][col] = SOLID_WALL
      -- Spawn areas MUST be empty
      elseif Map.is_spawn_area(row, col) then
        State.map[row][col] = EMPTY
      -- Grid pattern solid walls (odd row AND odd col, but not border)
      elseif row % 2 == 1 and col % 2 == 1 and row > 1 and col > 1 then
        State.map[row][col] = SOLID_WALL
      -- Random: breakable wall or empty
      else
        if math.random() < 0.7 then
          State.map[row][col] = BREAKABLE_WALL
        else
          State.map[row][col] = EMPTY
        end
      end
    end
  end
end

function Map.draw_shadows()
  for row = 1, MAP_HEIGHT do
    for col = 1, MAP_WIDTH do
      local tile = State.map[row][col]
      if tile == SOLID_WALL or tile == BREAKABLE_WALL then
        local drawX = (col - 1) * TILE_SIZE + BOARD_OFFSET_X
        local drawY = (row - 1) * TILE_SIZE + BOARD_OFFSET_Y
        rect(drawX + 1, drawY + 1, TILE_SIZE, TILE_SIZE, COLOR_SHADOW)
      end
    end
  end
end

function Map.draw_tiles()
  for row = 1, MAP_HEIGHT do
    for col = 1, MAP_WIDTH do
      local tile = State.map[row][col]
      local drawX = (col - 1) * TILE_SIZE + BOARD_OFFSET_X
      local drawY = (row - 1) * TILE_SIZE + BOARD_OFFSET_Y
      if tile == SOLID_WALL then
        spr(SOLID_WALL_SPRITE, drawX, drawY, 0, 1)
      elseif tile == BREAKABLE_WALL then
        spr(BREAKABLE_WALL_SPRITE, drawX, drawY, 0, 1)
      end
      -- Empty spaces use background color (no floor sprite)
    end
  end
end

--------------------------------------------------------------------------------
-- TopBar module
--------------------------------------------------------------------------------

function TopBar.draw()
  -- Background
  rect(0, 0, 240, 10, COLOR_SHADOW)
  -- Shadow
  rect(0, 10, 240, 2, COLOR_BLACK)

  local p1 = State.players[1]
  local p2 = State.players[2]

  -- Player 1 (left side) - blue
  if p1 then
    print("P1", 2, 2, COLOR_BLUE_LIGHT)
    print("W:"..State.score[1], 16, 2, COLOR_BLUE_LIGHT)
    print("B:"..p1.maxBombs, 40, 2, COLOR_YELLOW)
    print("P:"..p1.bombPower, 64, 2, COLOR_ORANGE)
  end

  -- Player 2 (right side) - red
  if p2 then
    print("P:"..p2.bombPower, 156, 2, COLOR_ORANGE)
    print("B:"..p2.maxBombs, 180, 2, COLOR_YELLOW)
    print("W:"..State.score[2], 204, 2, COLOR_RED)
    print("P2", 226, 2, COLOR_RED)
  end
end

--------------------------------------------------------------------------------
-- UI module (shared utilities)
--------------------------------------------------------------------------------

function UI.print_shadow(text, x, y, color, fixed, scale)
  scale = scale or 1
  print(text, x + 1, y + 1, COLOR_SHADOW, fixed, scale)
  print(text, x, y, color, fixed, scale)
end

--------------------------------------------------------------------------------
-- Splash module
--------------------------------------------------------------------------------

function Splash.update()
  cls(COLOR_BLACK)

  UI.print_shadow("Bomberman", 85, 50, COLOR_BLUE, false, 2)
  UI.print_shadow("Clone", 100, 70, COLOR_BLUE, false, 2)

  State.splash_timer = State.splash_timer - 1
  if State.splash_timer <= 0 then
    State.game_state = GAME_STATE_MENU
  end
end

--------------------------------------------------------------------------------
-- Menu module
--------------------------------------------------------------------------------

function Menu.update()
  cls(COLOR_BLACK)

  UI.print_shadow("Bomberman", 85, 20, COLOR_BLUE, false, 2)
  UI.print_shadow("Clone", 100, 40, COLOR_BLUE, false, 2)

  local unselected = COLOR_GRAY_LIGHT
  local p1_color = (State.menu_selection == 1) and COLOR_CYAN or unselected
  local p2_color = (State.menu_selection == 2) and COLOR_CYAN or unselected
  local help_color = (State.menu_selection == 3) and COLOR_CYAN or unselected
  local credits_color = (State.menu_selection == 4) and COLOR_CYAN or unselected
  local exit_color = (State.menu_selection == 5) and COLOR_CYAN or unselected

  local cursor_y = 60 + (State.menu_selection - 1) * 14
  UI.print_shadow(">", 60, cursor_y, COLOR_CYAN)

  UI.print_shadow("1 Player Game", 70, 60, p1_color)
  UI.print_shadow("2 Player Game", 70, 74, p2_color)
  UI.print_shadow("Help", 70, 88, help_color)
  UI.print_shadow("Credits", 70, 102, credits_color)
  UI.print_shadow("Exit", 70, 116, exit_color)

  if Input.up_pressed() then
    State.menu_selection = State.menu_selection - 1
    if State.menu_selection < 1 then State.menu_selection = 5 end
  elseif Input.down_pressed() then
    State.menu_selection = State.menu_selection + 1
    if State.menu_selection > 5 then State.menu_selection = 1 end
  elseif Input.action_pressed() then
    if State.menu_selection == 1 then
      State.two_player_mode = false
      State.game_state = GAME_STATE_PLAYING
      Game.init()
    elseif State.menu_selection == 2 then
      State.two_player_mode = true
      State.game_state = GAME_STATE_PLAYING
      Game.init()
    elseif State.menu_selection == 3 then
      State.game_state = GAME_STATE_HELP
    elseif State.menu_selection == 4 then
      State.game_state = GAME_STATE_CREDITS
    else
      exit()
    end
  end
end

--------------------------------------------------------------------------------
-- Help module
--------------------------------------------------------------------------------

function Help.update()
  cls(COLOR_BLACK)

  UI.print_shadow("Help", 100, 8, COLOR_BLUE, false, 2)

  -- Controls section
  UI.print_shadow("Controls", 20, 30, COLOR_LIGHT)

  -- P1 controls
  rect(20, 42, 90, 30, COLOR_SHADOW)
  rect(19, 41, 90, 30, COLOR_BLUE_LIGHT)
  print("Player 1 (Blue)", 22, 44, COLOR_LIGHT)
  print("Move: Arrow Keys", 22, 54, COLOR_LIGHT)
  print("Bomb: SPACE", 22, 64, COLOR_LIGHT)

  -- P2 controls
  rect(130, 42, 90, 30, COLOR_SHADOW)
  rect(129, 41, 90, 30, COLOR_RED)
  print("Player 2 (Red)", 132, 44, COLOR_LIGHT)
  print("Move: W A S D", 132, 54, COLOR_LIGHT)
  print("Bomb: G", 132, 64, COLOR_LIGHT)

  -- Powerups section
  UI.print_shadow("Powerups", 20, 80, COLOR_LIGHT)

  -- Bomb powerup
  rect(22, 93, 5, 5, COLOR_SHADOW)
  rect(21, 92, 5, 5, COLOR_YELLOW)
  print("B", 22, 92, COLOR_BLACK)
  print("+1 Bomb capacity", 32, 92, COLOR_YELLOW)

  -- Power powerup
  rect(22, 105, 5, 5, COLOR_SHADOW)
  rect(21, 104, 5, 5, COLOR_ORANGE)
  print("P", 22, 104, COLOR_BLACK)
  print("+1 Blast range", 32, 104, COLOR_ORANGE)

  -- Back instruction
  UI.print_shadow("Press SPACE to return", 60, 122, COLOR_CYAN)

  if Input.action_pressed() then
    State.game_state = GAME_STATE_MENU
  end
end

--------------------------------------------------------------------------------
-- Credits module
--------------------------------------------------------------------------------

function Credits.update()
  cls(COLOR_BLACK)

  UI.print_shadow("Credits", 90, 20, COLOR_BLUE, false, 2)

  UI.print_shadow("Author: Zsolt Tasnadi", 60, 50, COLOR_LIGHT)
  UI.print_shadow("Powered by Claude", 68, 66, COLOR_LIGHT)
  UI.print_shadow("Sponsored by Zen Heads", 52, 82, COLOR_LIGHT)
  UI.print_shadow("Happy X-MAS!", 80, 98, COLOR_RED)

  UI.print_shadow("Press SPACE to return", 60, 122, COLOR_CYAN)

  if Input.action_pressed() then
    State.game_state = GAME_STATE_MENU
  end
end

--------------------------------------------------------------------------------
-- WinScreen module
--------------------------------------------------------------------------------

function WinScreen.draw()
  cls(COLOR_BLACK)
  rect(20, 30, 200, 80, COLOR_BLUE)
  rect(22, 32, 196, 76, COLOR_BLACK)
  UI.print_shadow("PLAYER "..State.winner.." WON!", 70, 55, COLOR_BLUE, false, 2)
  if State.win_timer <= 0 or math.floor(State.win_timer / 15) % 2 == 0 then
    UI.print_shadow("Press SPACE (A) to restart", 55, 80, COLOR_BLUE)
  end
end

--------------------------------------------------------------------------------
-- GameBoard module
--------------------------------------------------------------------------------

function GameBoard.draw()
  Map.draw_shadows()
  Map.draw_tiles()
  Bomb.draw_explosions()
  Powerup.draw_all()
  Bomb.draw_all()

  -- draw players
  for idx, player in ipairs(State.players) do
    Player.draw(player.pixelX + BOARD_OFFSET_X, player.pixelY + BOARD_OFFSET_Y, idx == 1)
  end

  TopBar.draw()
end

--------------------------------------------------------------------------------
-- Bomb module (includes explosions)
--------------------------------------------------------------------------------

function Bomb.draw(x, y)
  spr(BOMB_SPRITE, x, y, 0, 1)
end

function Bomb.draw_all()
  for _, bomb in ipairs(State.bombs) do
    Bomb.draw(bomb.x + BOARD_OFFSET_X, bomb.y + BOARD_OFFSET_Y)
  end
end

function Bomb.draw_explosions()
  for _, expl in ipairs(State.explosions) do
    local drawX = expl.x + BOARD_OFFSET_X
    local drawY = expl.y + BOARD_OFFSET_Y
    if expl.spread <= 0 then
      rect(drawX, drawY, TILE_SIZE, TILE_SIZE, COLOR_RED)
    else
      local progress = 1 - (expl.spread / (expl.dist * SPREAD_DELAY))
      if progress > 0 then
        local size = math.floor(TILE_SIZE * progress)
        local off = math.floor((TILE_SIZE - size) / 2)
        rect(drawX + off, drawY + off, size, size, COLOR_RED)
      end
    end
  end
end

function Bomb.place(player)
  if player.activeBombs >= player.maxBombs then return end

  local bombX = (player.gridX - 1) * TILE_SIZE
  local bombY = (player.gridY - 1) * TILE_SIZE

  for _, b in ipairs(State.bombs) do
    if b.x == bombX and b.y == bombY then
      return
    end
  end

  table.insert(State.bombs, {
    x = bombX,
    y = bombY,
    timer = BOMB_TIMER,
    owner = player,
    power = player.bombPower
  })
  player.activeBombs = player.activeBombs + 1
end

function Bomb.explode(bombX, bombY, power)
  power = power or 1
  sfx(0, nil, 30)
  table.insert(State.explosions, {
    x = bombX,
    y = bombY,
    timer = EXPLOSION_TIMER,
    dist = 0,
    spread = 0
  })

  local gridX = math.floor(bombX / TILE_SIZE) + 1
  local gridY = math.floor(bombY / TILE_SIZE) + 1

  -- horizontal explosion
  for _, dir in ipairs({-1, 1}) do
    for dist = 1, power do
      local explX = bombX + dir * dist * TILE_SIZE
      local eGridX = gridX + dir * dist
      if eGridX < 1 or eGridX > MAP_WIDTH then break end
      local tile = State.map[gridY][eGridX]
      if tile == SOLID_WALL then break end
      if tile == BREAKABLE_WALL then
        State.map[gridY][eGridX] = EMPTY
        table.insert(State.explosions, {
          x = explX,
          y = bombY,
          timer = EXPLOSION_TIMER,
          dist = dist,
          spread = dist * SPREAD_DELAY
        })
        break
      end
      table.insert(State.explosions, {
        x = explX,
        y = bombY,
        timer = EXPLOSION_TIMER,
        dist = dist,
        spread = dist * SPREAD_DELAY
      })
    end
  end

  -- vertical explosion
  for _, dir in ipairs({-1, 1}) do
    for dist = 1, power do
      local explY = bombY + dir * dist * TILE_SIZE
      local eGridY = gridY + dir * dist
      if eGridY < 1 or eGridY > MAP_HEIGHT then break end
      local tile = State.map[eGridY][gridX]
      if tile == SOLID_WALL then break end
      if tile == BREAKABLE_WALL then
        State.map[eGridY][gridX] = EMPTY
        table.insert(State.explosions, {
          x = bombX,
          y = explY,
          timer = EXPLOSION_TIMER,
          dist = dist,
          spread = dist * SPREAD_DELAY
        })
        break
      end
      table.insert(State.explosions, {
        x = bombX,
        y = explY,
        timer = EXPLOSION_TIMER,
        dist = dist,
        spread = dist * SPREAD_DELAY
      })
    end
  end
end

function Bomb.update_all()
  -- update bombs
  for i = #State.bombs, 1, -1 do
    local bomb = State.bombs[i]
    bomb.timer = bomb.timer - 1
    if bomb.timer <= 0 then
      Bomb.explode(bomb.x, bomb.y, bomb.power)
      if bomb.owner then
        bomb.owner.activeBombs = bomb.owner.activeBombs - 1
      end
      table.remove(State.bombs, i)
    end
  end

  -- update explosions
  for i = #State.explosions, 1, -1 do
    local expl = State.explosions[i]
    if expl.spread > 0 then
      expl.spread = expl.spread - 1
    else
      expl.timer = expl.timer - 1
      if expl.timer <= 0 then
        table.remove(State.explosions, i)
      end
    end
  end
end

function Bomb.clear_all()
  State.bombs = {}
  State.explosions = {}
end

--------------------------------------------------------------------------------
-- AI module
--------------------------------------------------------------------------------

function AI.is_dangerous(gridX, gridY)
  -- Check active explosions
  for _, expl in ipairs(State.explosions) do
    local explGridX = math.floor(expl.x / TILE_SIZE) + 1
    local explGridY = math.floor(expl.y / TILE_SIZE) + 1
    if gridX == explGridX and gridY == explGridY then
      return true
    end
  end

  -- Check bombs about to explode (timer < 30) - need to escape!
  for _, bomb in ipairs(State.bombs) do
    local bombGridX = math.floor(bomb.x / TILE_SIZE) + 1
    local bombGridY = math.floor(bomb.y / TILE_SIZE) + 1
    local power = bomb.power or 1

    -- Only urgent if bomb is about to explode
    if bomb.timer < 30 then
      if gridX == bombGridX and gridY == bombGridY then
        return true
      end

      -- Check blast radius only for soon-to-explode bombs
      if gridY == bombGridY and math.abs(gridX - bombGridX) <= power then
        local blocked = false
        local minX = math.min(gridX, bombGridX)
        local maxX = math.max(gridX, bombGridX)
        for x = minX + 1, maxX - 1 do
          if State.map[gridY][x] == SOLID_WALL then
            blocked = true
            break
          end
        end
        if not blocked then return true end
      end

      if gridX == bombGridX and math.abs(gridY - bombGridY) <= power then
        local blocked = false
        local minY = math.min(gridY, bombGridY)
        local maxY = math.max(gridY, bombGridY)
        for y = minY + 1, maxY - 1 do
          if State.map[y][gridX] == SOLID_WALL then
            blocked = true
            break
          end
        end
        if not blocked then return true end
      end
    else
      -- For bombs with more time, just avoid the bomb cell itself
      if gridX == bombGridX and gridY == bombGridY then
        return true
      end
    end
  end

  return false
end

function AI.has_adjacent_breakable_wall(gridX, gridY)
  for _, dir in ipairs(DIRECTIONS) do
    local checkX = gridX + dir[1]
    local checkY = gridY + dir[2]
    if checkX >= 1 and checkX <= MAP_WIDTH and checkY >= 1 and checkY <= MAP_HEIGHT then
      if State.map[checkY][checkX] == BREAKABLE_WALL then
        return true
      end
    end
  end
  return false
end

function AI.find_nearest_powerup(gridX, gridY)
  local nearest = nil
  local nearestDist = 9999
  for _, pw in ipairs(State.powerups) do
    if State.map[pw.gridY][pw.gridX] == EMPTY then
      local dist = math.abs(pw.gridX - gridX) + math.abs(pw.gridY - gridY)
      if dist < nearestDist then
        nearestDist = dist
        nearest = pw
      end
    end
  end
  return nearest
end

function AI.is_in_blast_line(cellX, cellY, bombX, bombY, power)
  -- Check if cell is in same row or column as bomb and within power range
  if cellY == bombY and math.abs(cellX - bombX) <= power then
    return true
  end
  if cellX == bombX and math.abs(cellY - bombY) <= power then
    return true
  end
  return false
end

function AI.find_safe_cell(gridX, gridY, player)
  -- Find a cell to escape to that's OUTSIDE the bomb's blast line
  local power = player.bombPower

  -- First try: find a path that gets us completely out of blast line
  for _, dir in ipairs(DIRECTIONS) do
    local newX = gridX + dir[1]
    local newY = gridY + dir[2]
    if Map.can_move_to(newX, newY, player) and not AI.is_dangerous(newX, newY) then
      -- Check if this first step gets us out of blast line
      if not AI.is_in_blast_line(newX, newY, gridX, gridY, power) then
        return {newX, newY}
      end
      -- If not, check if we can turn corner to get out
      for _, dir2 in ipairs(DIRECTIONS) do
        local safeX = newX + dir2[1]
        local safeY = newY + dir2[2]
        if Map.can_move_to(safeX, safeY, player) and not AI.is_dangerous(safeX, safeY) then
          if not AI.is_in_blast_line(safeX, safeY, gridX, gridY, power) then
            return {newX, newY}
          end
        end
      end
    end
  end
  return nil
end

function AI.has_escape_route(gridX, gridY, player)
  return AI.find_safe_cell(gridX, gridY, player) ~= nil
end

function AI.escape_from_bomb(player)
  local safe = AI.find_safe_cell(player.gridX, player.gridY, player)
  if safe then
    player.gridX = safe[1]
    player.gridY = safe[2]
  end
end

function AI.move_and_bomb(player, target)
  if not target then return end

  -- Check for nearby powerup first
  local powerup = AI.find_nearest_powerup(player.gridX, player.gridY)
  local actualTarget = target

  -- If powerup is closer than target, go for powerup
  if powerup then
    local pwDist = math.abs(powerup.gridX - player.gridX) + math.abs(powerup.gridY - player.gridY)
    local targetDist = math.abs(target.gridX - player.gridX) + math.abs(target.gridY - player.gridY)
    if pwDist < targetDist or pwDist <= 5 then
      actualTarget = {gridX = powerup.gridX, gridY = powerup.gridY}
    end
  end

  local dx = actualTarget.gridX - player.gridX
  local dy = actualTarget.gridY - player.gridY
  local dist = math.abs(dx) + math.abs(dy)

  local should_bomb = false
  if dist <= 2 and actualTarget == target then should_bomb = true end
  if AI.has_adjacent_breakable_wall(player.gridX, player.gridY) then
    should_bomb = true
  end

  if should_bomb and player.activeBombs < player.maxBombs and player.bombCooldown <= 0 then
    if AI.has_escape_route(player.gridX, player.gridY, player) then
      player.lastGridX = player.gridX
      player.lastGridY = player.gridY
      Bomb.place(player)
      player.bombCooldown = AI_BOMB_COOLDOWN
      AI.escape_from_bomb(player)
      return
    end
  end

  -- Build direction list (preferred directions first, then all others)
  local dirs = {}
  if dx > 0 then table.insert(dirs, {1, 0})
  elseif dx < 0 then table.insert(dirs, {-1, 0})
  end
  if dy > 0 then table.insert(dirs, {0, 1})
  elseif dy < 0 then table.insert(dirs, {0, -1})
  end

  for _, d in ipairs(DIRECTIONS) do
    table.insert(dirs, d)
  end

  -- Try to move, avoiding going back to last position unless necessary
  local fallback = nil
  for _, dir in ipairs(dirs) do
    local newGridX = player.gridX + dir[1]
    local newGridY = player.gridY + dir[2]
    if Map.can_move_to(newGridX, newGridY, player) and not AI.is_dangerous(newGridX, newGridY) then
      -- Avoid going back unless it's the only option
      if newGridX == player.lastGridX and newGridY == player.lastGridY then
        if not fallback then fallback = {newGridX, newGridY} end
      else
        player.lastGridX = player.gridX
        player.lastGridY = player.gridY
        player.gridX = newGridX
        player.gridY = newGridY
        return
      end
    end
  end

  -- Use fallback if no other option
  if fallback then
    player.lastGridX = player.gridX
    player.lastGridY = player.gridY
    player.gridX = fallback[1]
    player.gridY = fallback[2]
  end
end

function AI.update(player, target)
  -- Even while moving, check if destination becomes dangerous
  if player.moving then
    if AI.is_dangerous(player.gridX, player.gridY) then
      -- Destination is dangerous! Try to stop or reverse
      local currentGridX = math.floor(player.pixelX / TILE_SIZE) + 1
      local currentGridY = math.floor(player.pixelY / TILE_SIZE) + 1
      if not AI.is_dangerous(currentGridX, currentGridY) then
        -- Stay at current position
        player.gridX = currentGridX
        player.gridY = currentGridY
      end
    end
    return
  end

  local in_danger = AI.is_dangerous(player.gridX, player.gridY)

  if in_danger then
    local best_dir = nil
    local best_safe = false

    for _, dir in ipairs(DIRECTIONS) do
      local newX = player.gridX + dir[1]
      local newY = player.gridY + dir[2]
      if Map.can_move_to(newX, newY, player) then
        local safe = not AI.is_dangerous(newX, newY)
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
  if player.moveTimer < AI_MOVE_DELAY then return end

  player.moveTimer = 0
  AI.move_and_bomb(player, target)
end

--------------------------------------------------------------------------------
-- Player module
--------------------------------------------------------------------------------

function Player.draw(x, y, is_player1)
  local sprite_id = is_player1 and PLAYER_BLUE or PLAYER_RED
  spr(sprite_id, x, y, 0, 1)
end

function Player.create(gridX, gridY, color, is_ai)
  return {
    gridX = gridX,
    gridY = gridY,
    lastGridX = gridX,
    lastGridY = gridY,
    pixelX = (gridX - 1) * TILE_SIZE,
    pixelY = (gridY - 1) * TILE_SIZE,
    moving = false,
    maxBombs = 1,
    activeBombs = 0,
    bombPower = 1,
    color = color,
    is_ai = is_ai,
    moveTimer = 0,
    bombCooldown = 0,
    spawnX = gridX,
    spawnY = gridY
  }
end

function Player.update_movement(player)
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

function Player.handle_input(player, input)
  if player.moving then return end

  local newGridX = player.gridX
  local newGridY = player.gridY

  if input.up() then
    newGridY = player.gridY - 1
  elseif input.down() then
    newGridY = player.gridY + 1
  elseif input.left() then
    newGridX = player.gridX - 1
  elseif input.right() then
    newGridX = player.gridX + 1
  end

  if Map.can_move_to(newGridX, newGridY, player) then
    player.gridX = newGridX
    player.gridY = newGridY
  end

  if input.action() then
    Bomb.place(player)
  end
end

-- Input configurations for each player
local P1_INPUT = {
  up = Input.up,
  down = Input.down,
  left = Input.left,
  right = Input.right,
  action = Input.action_pressed
}

local P2_INPUT = {
  up = Input.p2_up,
  down = Input.p2_down,
  left = Input.p2_left,
  right = Input.p2_right,
  action = Input.p2_action
}

function Player.reset(player)
  player.gridX = player.spawnX
  player.gridY = player.spawnY
  player.pixelX = (player.spawnX - 1) * TILE_SIZE
  player.pixelY = (player.spawnY - 1) * TILE_SIZE
  player.moving = false
  player.maxBombs = 1
  player.activeBombs = 0
  player.bombPower = 1
  player.bombCooldown = 0
end

--------------------------------------------------------------------------------
-- Game module
--------------------------------------------------------------------------------

function Game.init()
  State.winner = nil
  State.win_timer = 0
  Bomb.clear_all()
  Map.generate()

  State.players = {}
  table.insert(State.players, Player.create(2, 2, COLOR_BLUE, false))
  local p2_is_ai = not State.two_player_mode
  table.insert(State.players, Player.create(MAP_WIDTH - 1, MAP_HEIGHT - 1, COLOR_RED, p2_is_ai))

  Powerup.init()
end

function Game.restart()
  State.winner = nil
  State.win_timer = 0
  Bomb.clear_all()
  Map.generate()

  for _, p in ipairs(State.players) do
    Player.reset(p)
  end

  Powerup.init()
end

function Game.set_winner(player_num)
  State.winner = player_num
  State.win_timer = WIN_SCREEN_DURATION
  State.score[player_num] = State.score[player_num] + 1
end

function Game.check_death_by_explosion()
  for idx, player in ipairs(State.players) do
    for _, expl in ipairs(State.explosions) do
      if expl.spread <= 0 then
        local explGridX = math.floor(expl.x / TILE_SIZE) + 1
        local explGridY = math.floor(expl.y / TILE_SIZE) + 1
        if player.gridX == explGridX and player.gridY == explGridY then
          local winner_idx = (idx == 1) and 2 or 1
          Game.set_winner(winner_idx)
          return true
        end
      end
    end
  end
  return false
end

function Game.update()
  -- Get human player as target for AI
  local human_player = State.players[1]

  -- update all players
  for idx, player in ipairs(State.players) do
    Player.update_movement(player)
    if player.is_ai then
      AI.update(player, human_player)
    else
      local input = (idx == 1) and P1_INPUT or P2_INPUT
      Player.handle_input(player, input)
    end
  end

  Bomb.update_all()
  Powerup.check_pickup()

  if Game.check_death_by_explosion() then return true end
  return false
end

--------------------------------------------------------------------------------
-- Main game loop
--------------------------------------------------------------------------------

function TIC()
  if State.game_state == GAME_STATE_SPLASH then
    Splash.update()
    return
  elseif State.game_state == GAME_STATE_MENU then
    Menu.update()
    return
  elseif State.game_state == GAME_STATE_HELP then
    Help.update()
    return
  elseif State.game_state == GAME_STATE_CREDITS then
    Credits.update()
    return
  end

  -- GAME_STATE_PLAYING
  cls(COLOR_GREEN)

  if State.winner then
    State.win_timer = State.win_timer - 1
    WinScreen.draw()
    if Input.action_pressed() and State.win_timer <= 0 then
      Game.restart()
    end
    return
  end

  if Game.update() then return end

  GameBoard.draw()
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
-- 000:f0e0d0c0b0a090807060504030201000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020500000
-- 001:050005000500050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000305000000000
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
