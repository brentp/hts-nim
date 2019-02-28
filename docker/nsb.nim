# nim static builder
# to be run inside the docker container
import docopt
import os
import osproc
import strformat
import strutils

let doc = """
nim-static-builder

Usage: nsb [options --deps <string>...] [--] [<nim_compiler_args>...]

Options:

  -n --nimble-file <string>            optional path to nimble file
  -s --nim-src-file <string>           required path to nim file to be compiled to binary
  -d --deps <string>...                 any number of dependencies, e.g. --deps "hts@>=0.2.7" --deps "lapper"

"""

echo commandLineParams()

let args = docopt(doc)

echo $args

if $args["--nim-src-file"] == "nil":
  echo doc
  echo "source file required"
  quit 1

var source = expandFilename($args["--nim-src-file"])
if not existsFile(source):
  quit "couldn't find source file"

var path = getEnv("PATH")
path &= ":/nim/bin"
putEnv("PATH", path)

for d in @(args["--deps"]):
  if 0 != execCmd(&"""nimble install -y "{d}" """):
    quit "failed on nimble install of " & d

if $args["--nimble-file"] != "nil":
  var (dir, _, _) = splitFile(expandFileName($args["--nimble-file"]))
  dir.setCurrentDir

  if execCmd(&"""sh -c "export PATH={path}; /nim/bin/nimble install -d -y " """) != 0:
    quit "coudn't run nimble install"


var (dir, name, _) = splitFile(source)
dir.setCurrentDir

removeFile("xx_exe_out")
var cmd = &"""/nim/bin/nim c -d:nsb_static {join(@(args["<nim_compiler_args>"]), " ")} -o:xx_exe_out {name}"""
if execCmd(&"""sh -c "{cmd}" """) != 0:
  quit "error compiling code"

copyFileWithPermissions("xx_exe_out", &"/load/{name}")
removeFile("xx_exe_out")

echo &"wrote executable: {name}"
