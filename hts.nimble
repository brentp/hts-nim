# Package

version       = "0.3.23"
author        = "Brent Pedersen"
description   = "hts (bam/sam) for nim"
license       = "MIT"


# Dependencies

requires "nim >= 0.19.9"
srcDir = "src"

skipDirs = @["tests"]
skipFiles = @["teloage.nim"]

import os, strutils

task test, "run the tests":
  exec "nim c  -d:useSysAssert -d:useGcAssert --lineDir:on --debuginfo -r tests/all"

#before test:
#  exec "c2nim src/hts/private/hts_concat.h"

task docs, "Builds documentation":
  mkDir("docs"/"hts")
  #exec "nim doc2 --verbosity:0 --hints:off -o:docs/index.html  src/hts.nim"
  for file in listfiles("src/hts"):
    if file.endswith("value.nim"): continue
    if splitfile(file).ext == ".nim":
      exec "nim doc2 --verbosity:0 --hints:off -o:" & "docs" /../ file.changefileext("html").split("/", 1)[1] & " " & file

