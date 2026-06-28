# OpenJazz2

OpenJazz2 is a from-scratch re-implementation of the classic platformer game **Jazz Jackrabbit 2** (1998, Epic MegaGames) written in **Zig**. It reads the original game's data files and renders them using modern OpenGL 3.3 through SDL3.

> **Status:** Early development / pre-alpha. The engine can load and display levels,
> tilesets, animations, and play music, but the game is not yet playable.

## Features

### Implemented
- **Asset reading** — `.j2t` tilesets, `.j2a` animation sets, `.j2l` levels, `.j2b` music
- **8-layer level rendering** with parallax scrolling, auto-scroll, tile wrapping
- **Animated tiles** with ping-pong frame cycling
- **Indexed & full-color sprite rendering** via OpenGL 3.3 Core shaders
- **Player** — Jazz character with movement, jumping, buttstomp, and basic physics
- **Animation system** — time-based frame calculation with RLE decoding
- **J2B music playback** via libopenmpt
- **In-game developer console** (toggle with `~`)
- **FPS counter** and collision mask overlay
- **Diagnostic tools** — standalone viewers for tilesets, animations, levels, and audio

### Not yet implemented
- Collision detection against tiles
- Enemies, weapons, items, power-ups
- Menus, HUD, scoring
- Sound effects
- Network / multiplayer

## Requirements

- **Zig** `0.16.0-dev.747+493ad58ff` or later
- **SDL3** — `apt install libsdl3-dev`
- **SDL3_ttf** — build from [source](https://github.com/libsdl-org/SDL_ttf) (needs `libfreetype-dev`)
- **SDL3_mixer** — `apt install libsdl3-mixer-dev`
- **libopenmpt** — `apt install libopenmpt-dev` (loaded at runtime via `dlopen`)
- **OpenGL 3.3** compatible GPU + drivers
- Original **Jazz Jackrabbit 2** game data files (.j2t, .j2a, .j2l, .j2b)

## Building

```bash
# Clone the repo
git clone <url>
cd openjazz2/src

# Build
zig build

# Build and run (game mode)
zig build run

# Build and run with CLI arguments
zig build run -- level /path/to/level.j2l

# Run tests
zig build test
```

The binary is placed at `zig-out/bin/openjazz2`.

## Usage

```
openjazz2 [command] [options]

Commands:
  game                        Run the main game (default)
  tileset <file.j2t>          Load and display a tileset file
  animset <file.j2a>          Load and display an animation set
  level <file.j2l>            Load and display a level
  sound <file.j2b>            Play a music/sound file
  gfx                         Test the graphics system
  help                        Show this help
```

### Console commands (press `~` in-game)
- `help` — list available commands
- `show mask` / `hide mask` — toggle collision mask overlay
- `show cam_pos` — show camera position

## Project structure

```
openjazz2/src/
  build.zig              Build script
  build.zig.zon          Package manifest
  src/
    main.zig             Entry point & CLI dispatcher
    app.zig              IApp vtable interface
    game.zig             Main game loop & state
    assets.zig           Data model types
    assets_reader.zig    Binary file parsers (.j2t, .j2a, .j2l, .j2b)
    assets_maps.zig      Animation & event enums/constants
    player.zig           Player entity (Jazz/Spaz)
    level_view.zig       Level rendering & parallax
    console.zig          In-game developer console
    g_math.zig           Coordinate types (Tile, World, Screen)
    g_anim.zig           Animation frame calculation
    diag_*.zig           Diagnostic tools
    gfx/                 Graphics module (SDL3, OpenGL, shaders)
    utils/               Utilities (file I/O, binary serialization)
  test_data/             Sample tilesets for testing
```

## Testing

Tests are written inline using Zig's built-in `test` blocks. Run them with:

```bash
zig build test
```

Test files are enumerated in `build.zig`. The `test_data/` directory contains sample
asset files used by the test suite.

## License

GNU General Public License v3.0. See [LICENSE](../LICENSE).
