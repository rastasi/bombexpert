-- title:  Simple Bomberman
-- author: Claude
-- script: lua

-- constants
TILE_SIZE=16
PLAYER_SIZE=12
BOMB_TIMER=90
EXPLOSION_TIMER=30

EMPTY=0
SOLID_WALL=1
BREAKABLE_WALL=2

-- player
playerX=16
playerY=16

-- game objects
bombs={}
explosions={}

-- enemy
enemy={
 x=208,
 y=112,
 dir=0,
 moveTimer=0
}

-- 1=solid wall, 2=breakable wall
map={
 {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
 {1,0,0,2,2,2,0,2,0,2,2,2,0,0,1},
 {1,0,1,2,1,2,1,2,1,2,1,2,1,0,1},
 {1,2,2,2,0,2,2,0,2,2,0,2,2,2,1},
 {1,2,1,0,1,0,1,0,1,0,1,0,1,2,1},
 {1,2,2,2,0,2,2,0,2,2,0,2,2,2,1},
 {1,0,1,2,1,2,1,2,1,2,1,2,1,0,1},
 {1,0,0,2,2,2,0,2,0,2,2,2,0,0,1},
 {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
}

function TIC()
 cls(0)

 -- handle input
 newX=playerX
 newY=playerY

 if btn(0) then newY=playerY-1 end
 if btn(1) then newY=playerY+1 end
 if btn(2) then newX=playerX-1 end
 if btn(3) then newX=playerX+1 end

 if not isSolid(newX,playerY) then playerX=newX end
 if not isSolid(playerX,newY) then playerY=newY end

 -- place bomb
 if btnp(4) then
  bombX=math.floor(playerX/TILE_SIZE)*TILE_SIZE
  bombY=math.floor(playerY/TILE_SIZE)*TILE_SIZE
  table.insert(bombs,{x=bombX,y=bombY,timer=BOMB_TIMER})
 end

 -- update bombs
 for i=#bombs,1,-1 do
  bombs[i].timer=bombs[i].timer-1
  if bombs[i].timer<=0 then
   explode(bombs[i].x,bombs[i].y)
   table.remove(bombs,i)
  end
 end

 -- update explosions
 for i=#explosions,1,-1 do
  explosions[i].timer=explosions[i].timer-1
  if explosions[i].timer<=0 then
   table.remove(explosions,i)
  end
 end

 -- draw map
 for row=1,9 do
  for col=1,15 do
   tile=map[row][col]
   drawX=(col-1)*TILE_SIZE
   drawY=(row-1)*TILE_SIZE
   if tile==SOLID_WALL then
    rect(drawX,drawY,TILE_SIZE,TILE_SIZE,8)
   elseif tile==BREAKABLE_WALL then
    rect(drawX,drawY,TILE_SIZE,TILE_SIZE,4)
   end
  end
 end

 -- draw bombs
 for i=1,#bombs do
  bomb=bombs[i]
  circ(bomb.x+8,bomb.y+8,6,2)
 end

 -- draw explosions
 for i=1,#explosions do
  expl=explosions[i]
  rect(expl.x,expl.y,TILE_SIZE,TILE_SIZE,6)
 end

 -- update enemy
 updateEnemy()

 -- draw player
 rect(playerX,playerY,PLAYER_SIZE,PLAYER_SIZE,12)

 -- draw enemy
 rect(enemy.x,enemy.y,PLAYER_SIZE,PLAYER_SIZE,2)

 -- check player death by explosion
 for i=1,#explosions do
  expl=explosions[i]
  if playerX<expl.x+TILE_SIZE and playerX+PLAYER_SIZE>expl.x and
     playerY<expl.y+TILE_SIZE and playerY+PLAYER_SIZE>expl.y then
   playerX=16
   playerY=16
  end
 end

 -- check player death by enemy
 if playerX<enemy.x+PLAYER_SIZE and playerX+PLAYER_SIZE>enemy.x and
    playerY<enemy.y+PLAYER_SIZE and playerY+PLAYER_SIZE>enemy.y then
  playerX=16
  playerY=16
 end

 -- check enemy death by explosion
 for i=1,#explosions do
  expl=explosions[i]
  if enemy.x<expl.x+TILE_SIZE and enemy.x+PLAYER_SIZE>expl.x and
     enemy.y<expl.y+TILE_SIZE and enemy.y+PLAYER_SIZE>expl.y then
   enemy.x=208
   enemy.y=112
  end
 end

 print("ARROWS:MOVE A:BOMB",50,2,15)
end

function isSolid(x,y)
 gridLeft=math.floor(x/TILE_SIZE)+1
 gridTop=math.floor(y/TILE_SIZE)+1
 gridRight=math.floor((x+PLAYER_SIZE-1)/TILE_SIZE)+1
 gridBottom=math.floor((y+PLAYER_SIZE-1)/TILE_SIZE)+1

 if gridLeft<1 or gridTop<1 or gridRight>15 or gridBottom>9 then
  return true
 end
 if map[gridTop][gridLeft]>=SOLID_WALL then return true end
 if map[gridTop][gridRight]>=SOLID_WALL then return true end
 if map[gridBottom][gridLeft]>=SOLID_WALL then return true end
 if map[gridBottom][gridRight]>=SOLID_WALL then return true end
 return false
end

function updateEnemy()
 enemy.moveTimer=enemy.moveTimer+1
 if enemy.moveTimer<3 then return end
 enemy.moveTimer=0

 -- try current direction
 dirs={{0,-1},{0,1},{-1,0},{1,0}}
 dx=dirs[enemy.dir+1] and dirs[enemy.dir+1][1] or 0
 dy=dirs[enemy.dir+1] and dirs[enemy.dir+1][2] or 0

 newEnemyX=enemy.x+dx
 newEnemyY=enemy.y+dy

 if not isSolidForEnemy(newEnemyX,newEnemyY) and math.random()>0.1 then
  enemy.x=newEnemyX
  enemy.y=newEnemyY
 else
  enemy.dir=math.random(0,3)
 end
end

function isSolidForEnemy(x,y)
 gridLeft=math.floor(x/TILE_SIZE)+1
 gridTop=math.floor(y/TILE_SIZE)+1
 gridRight=math.floor((x+PLAYER_SIZE-1)/TILE_SIZE)+1
 gridBottom=math.floor((y+PLAYER_SIZE-1)/TILE_SIZE)+1

 if gridLeft<1 or gridTop<1 or gridRight>15 or gridBottom>9 then
  return true
 end
 if map[gridTop][gridLeft]>=SOLID_WALL then return true end
 if map[gridTop][gridRight]>=SOLID_WALL then return true end
 if map[gridBottom][gridLeft]>=SOLID_WALL then return true end
 if map[gridBottom][gridRight]>=SOLID_WALL then return true end
 return false
end

function explode(bombX,bombY)
 table.insert(explosions,{x=bombX,y=bombY,timer=EXPLOSION_TIMER})

 -- horizontal explosion
 for dir=-1,1,2 do
  explX=bombX+dir*TILE_SIZE
  gridX=math.floor(explX/TILE_SIZE)+1
  gridY=math.floor(bombY/TILE_SIZE)+1
  if gridX>=1 and gridX<=15 then
   tile=map[gridY][gridX]
   if tile==EMPTY then
    table.insert(explosions,{x=explX,y=bombY,timer=EXPLOSION_TIMER})
   elseif tile==BREAKABLE_WALL then
    map[gridY][gridX]=EMPTY
    table.insert(explosions,{x=explX,y=bombY,timer=EXPLOSION_TIMER})
   end
  end
 end

 -- vertical explosion
 for dir=-1,1,2 do
  explY=bombY+dir*TILE_SIZE
  gridX=math.floor(bombX/TILE_SIZE)+1
  gridY=math.floor(explY/TILE_SIZE)+1
  if gridY>=1 and gridY<=9 then
   tile=map[gridY][gridX]
   if tile==EMPTY then
    table.insert(explosions,{x=bombX,y=explY,timer=EXPLOSION_TIMER})
   elseif tile==BREAKABLE_WALL then
    map[gridY][gridX]=EMPTY
    table.insert(explosions,{x=bombX,y=explY,timer=EXPLOSION_TIMER})
   end
  end
 end
end
