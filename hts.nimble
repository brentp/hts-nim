# Package

version       = "0.1.4"
author        = "Brent Pedersen"
description   = "hts (bam/sam) for nim"
license       = "MIT"

# Dependencies

requires "nim >= 0.17.2" #, "nim-lang/c2nim>=0.9.13"

skipDirs = @["tests"]
skipFiles = @["teloage.nim"]

task test, "run the tests":
  exec "nim c --lineDir:on --debuginfo -r tests/all"

before test:
  exec "c2nim hts/hts_concat.h"

task docs, "make docs":
  exec "nim doc2 hts; mkdir -p docs; mv hts.html docs/index.html"
