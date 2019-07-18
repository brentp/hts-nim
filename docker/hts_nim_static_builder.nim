# nim static builder
# to be run outside the docker container
import docopt
import os
import osproc
import strformat
import strutils

let doc = """
static-builder

Usage: static-builder [options --deps <string>...] [--] [<nim_compiler_args>...]

`nim_compiler_args` are passed on directly to the nim compiler, e.g. --excessiveStackTrace:on

Options:

  -n --nimble-file <string>            optional path to nimble file must be in the same or parent directory of the nim source file.
  -s --nim-src-file <string>           required path to nim file to be compiled to binary
  -x --debug                           debug build. default is to build in release mode.
  -t --tag <string>                    docker tag to use [default: latest]
  -d --deps <string>...                any number of dependencies, e.g. --deps "hts@>=0.2.7" --deps "lapper"

"""

let args = docopt(doc)

echo $args

if $args["--nim-src-file"] == "nil":
  echo doc
  echo "source file required"
  quit 1

var source = expandFilename($args["--nim-src-file"])
if not existsFile(source):
  quit "couldn't find source file"

var dir: string
var nimblePath: string

if $args["--nimble-file"] != "nil":
  nimblePath = expandFileName($args["--nimble-file"])
  var (d, _, _) = splitFile(nimblePath)
  dir = d
else:
   var (d, name, _) = splitFile(source)
   dir = d

# file gets build and sent to /load so it appears in the users pwd
var cmd = &"""docker run -v {dir}:{dir} -v {getCurrentDir()}:/load/ brentp/musl-hts-nim:{$args["--tag"]} /usr/local/bin/nsb """
if $args["--nimble-file"] != "nil":
  cmd &= &"""-n {nimblePath}"""

cmd &= &""" -s {source}"""

for d in @(args["--deps"]):
  cmd &= &""" --deps "{d}" """

var added_dash = false
if len(@(args["<nim_compiler_args>"])) > 0:
  cmd &= &""" -- {join(@(args["<nim_compiler_args>"]), " ")}"""
  added_dash = true

if not args["--debug"]:
  if not added_dash:
    cmd &= " -- "
  cmd &= " -d:danger -d:release"

echo cmd

if execCmd(cmd) != 0:
  quit "failed"
