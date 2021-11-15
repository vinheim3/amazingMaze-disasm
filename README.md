# Common
* Place `prgRom.bin` in the `tools/` directory, and `web/` directory
* Former is used for scripts, and `tools/cmp.sh`, and the latter for web visualisations

# Building
* Run `make` within the `disasm` directory
* Run `tools/cmp.sh` to compare built ROM against original ROM

# Web
* Start a web server within the `web/` directory, eg `python3 -m http.server`
* Navigate to the root page to see a list of game screens and sprites (TODO)

# Project Structure
* `disasm`
  * `code` - dissected and commented asm that runs the game
  * `gfx` - pngs of 1bpp data (not used for build)
  * `include` - constants, hardware definitions, ram, macros and structs
* `tools` - misc tools to help with disassembly
* `web` - the html+js in 1 file to visualise

# Note on improvements
The project serves to describe everything that makes the game function as it does. Some things are not completely clear from the outset. If you need a full guide on a particular concept, or some part of the disassembly needs further clarification, please feel free to raise an issue