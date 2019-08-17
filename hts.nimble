# Package

version       = "0.2.20"
author        = "Brent Pedersen"
description   = "hts (bam/sam) for nim"
license       = "MIT"


# Dependencies

requires "nim >= 0.18.0" 
srcDir = "src"

skipDirs = @["tests"]
skipFiles = @["teloage.nim"]

import ospaths,strutils

task test, "run the tests":
  exec "nim c --lineDir:on --debuginfo -r tests/all"

#before test:
#  exec "c2nim src/hts/private/hts_concat.h"

task docs, "Builds documentation":
  mkDir("docs"/"hts")
  #exec "nim doc2 --verbosity:0 --hints:off -o:docs/index.html  src/hts.nim"
  for file in listfiles("src/hts"):
    if file.endswith("value.nim"): continue
    if splitfile(file).ext == ".nim":
      exec "nim doc2 --verbosity:0 --hints:off -o:" & "docs" /../ file.changefileext("html").split("/", 1)[1] & " " & file

