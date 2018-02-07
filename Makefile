
name    := TwistIT-by-Resistance-2018

libsfx_dir	:= ./libSFX
libsfx_packages := LZ4

# music (SPC file)
music_path      := data/SNEStronizer
derived_files   += data/music.bin

# text
derived_files   += data/introtext2.txt.lz4

# Logo graphics
derived_files	+= data/snes_rse_logo.png.palette data/snes_rse_logo.png.tiles
derived_files   += data/snes_rse_logo.png.tiles.lz4
data/snes_rse_logo.png.tiles: tiles_flags = --no-discard --no-flip

# Font graphics
derived_files   += data/font_fra.png.palette data/font_fra.png.tiles
derived_files   += data/font_fra.png.tiles.lz4
data/font_fra.png.tiles: tiles_flags = --no-discard --no-flip

# Twister graphics
derived_files	+= data/twist.png.palette data/twist.png.tiles data/twist.png.map
derived_files   += data/twist.png.tiles.lz4 data/twist.png.map.lz4
data/twist.png.palette: palette_flags = --no-remap

# 2bpp background graphics
derived_files	+= data/snes-bg.png.palette data/snes-bg.png.tiles data/snes-bg.png.map
derived_files   += data/snes-bg.png.tiles.lz4 data/snes-bg.png.map.lz4
data/snes-bg.png.palette: palette_flags = -C 4
data/snes-bg.png.tiles: tiles_flags = -B 2
data/snes-bg.png.map: map_flags = -B 2

# Include libSFX.make
# (using my own modified one to cut out some stuff that this small intro doesn't need)
include ./libSFX.make

# pack part of a SPC file instead of using snesmod's sound bank loader (for convenience)
data/music.bin: $(music_path).spc
	dd if="$<" bs=256 skip=3 count=253 | $(lz4_compress) $(lz4_flags) - "$@"

