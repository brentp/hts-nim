# Package

version       = "0.1.1"
author        = "Brent Pedersen"
description   = "hts (bam/sam) for nim"
license       = "MIT"

# Dependencies

requires "nim >= 0.17.0" #, "nim-lang/c2nim>=0.9.13"

skipDirs = @["tests"]

task test, "run the tests":
  exec "nim c -r tests/all"

before test:
  exec "c2nim hts/hts_concat.h"

task docs, "make docs":
  exec "nim doc2 hts/hts; mkdir -p docs; mv hts.html docs/index.html"
