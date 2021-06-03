import os, osproc
import random
import strformat
import strutils
import terminal
import unittest


randomize()

proc getRandomNimname(length: int = 8): string =
  result = "test_"
  for _ in 0..length:
    result.add(sample(IdentChars))
  result.add(".nim")

proc saveNimCode(codeLines: seq[string]): string =
  # Write codeLines to a temporary file and return the filename
  result = getRandomNimname()
  var output = open(result, fmWrite)
  for line in codeLines:
    if line == "import hts":
      # Use the current hts package, not the installed one
      output.writeLine(line.replace("hts", "src/hts"))
    else:
      output.writeLine(line)
  output.close()

proc compileRun(filename: string): bool =
  ## Compile and Run
  result = true
  let commands = @[
    ("Compile", &"nim c -d:release {filename}"),
    ("Run", &"{CurDir}{DirSep}{filename.changeFileExt(ExeExt)}")]

  for command in commands:
    var (outp, errC) = execCmdEx(command[1])
    if errC > 0:
      stdout.styledWrite(fgRed, styleBright, "  [FAILED] ")
      echo &"{command[0]} Readme sample"
      echo outp
      result = false


suite "Ensure the samples included in Readme.md works as intended":
  test "Code extraction and running.":
    var readme: File = open("README.md")
    defer: readme.close()

    var codeSample: seq[string]
    var inSnippet: bool = false
    var readmeLines: int

    for line in readme.lines:
      readmeLines.inc

      if line.startsWith("```nim"):  # Starting a snippet code
        inSnippet = true
        continue

      if inSnippet:
        if not line.startsWith("```"):  # Save every line of the snippet
          codeSample.add(line)
        else:  # The end of the snippet in reached
          inSnippet = false

          var testFilename = saveNimCode(codeSample)
          try:
            doAssert compileRun(testFilename)
            echo "  Success: Readme.md sample code between ",
              &"lines {readmeLines - codeSample.len} and {readmeLines} ",
              "seems OK."
          except AssertionError:
            echo "  Error: Readme.md sample code raised the above error between ",
              &"lines {readmeLines - codeSample.len} and {readmeLines}."
            raise newException(AssertionError, getCurrentExceptionMsg())
          finally:
            # Clear code sample and remove temp files
            codeSample = @[]
            removeFile(testFilename)
            removeFile(testFilename.changeFileExt(ExeExt))
