# Jazz Jack Rabbit 2 Zig implementation

## Building sources

1. Install the following packages
 - SDL3 `apt install libsdl3-dev`
 - SDL3_ttf 
 -- Download sources from https://github.com/libsdl-org/SDL_ttf
 -- Install dependencies: `apt install libfreetype-dev`
 -- Build SDL3_ttf: `cmake -S . -B build; cd build; make`
 -- Install SDL3_ttf `(sudo) make install`
