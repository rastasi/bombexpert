# Bomberman Clone

A classic Bomberman clone for [TIC-80](https://tic80.com/) fantasy console.

## Features

- 1 Player mode (vs AI)
- 2 Player local multiplayer
- Grid-based movement with smooth animation
- Destructible walls
- Power-ups:
  - **B** (yellow): +1 bomb capacity
  - **P** (orange): +1 blast range
- Smart AI opponent that seeks power-ups and avoids explosions
- Score tracking across rounds

## Controls

### Player 1 (Blue)
| Action | Key |
|--------|-----|
| Move | Arrow Keys |
| Place Bomb | Space |

### Player 2 (Red)
| Action | Key |
|--------|-----|
| Move | W, A, S, D |
| Place Bomb | G |

### Menu Navigation
| Action | Key |
|--------|-----|
| Navigate | Up / Down |
| Select | Space |
| Back / Exit | Backspace |

## How to Play

1. Run the game in TIC-80
2. Select "1 Player Game" or "2 Player Game" from the menu
3. Navigate through the maze and place bombs to destroy breakable walls
4. Collect power-ups to increase your bomb capacity and blast range
5. Eliminate your opponent by catching them in an explosion
6. First player to win the round scores a point

## Running the Game

### In TIC-80
```bash
load bomberman.lua
run
```

### In Browser
Use the HTML export in the `bomberman/` folder with the included server:
```bash
python serve.py
```
Then open http://localhost:3333 in your browser.

## Requirements

- [TIC-80](https://tic80.com/) fantasy console (free version works)
- Or any modern web browser (for HTML export)

## Project Structure

```
bomberman/
├── bomberman.lua    # Main game source code
├── serve.py         # Simple HTTP server for browser testing
└── README.md        # This file
```

## Credits

- **Author**: Zsolt Tasnadi
- **Powered by**: Claude
- **Sponsored by**: Zen Heads

## License

MIT License

---

Happy X-MAS!
