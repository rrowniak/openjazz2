# OpenJazz2

OpenJazz2 is a from-scratch re-implementation of the classic platformer **Jazz Jackrabbit 2**.
It reads the original game's data files and renders them using modern OpenGL via SDL3.

## Implementations

- **[Zig](src/)** — Active development. Loads and displays levels, tilesets, animations;
  plays music; basic player physics. See `src/README.md` for build instructions and usage.
- **[C++](cpp/)** — Older implementation using C++11/14, SDL2, CMake. On hold.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
