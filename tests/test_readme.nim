import os, osproc
import random
import strformat
import strutils
import unittest


randomize()

proc getRandomNimname(length: int = 8): string =
  result = "test_"
  for _ in ..length:
    result.add(sample(IdentChars))
  result.add(".nim")

suite "Ensure the samples included in Readme.md works as intended":
  test "Code extraction and running.":
    var readme: File = open("README.md")
    defer: readme.close()

    var codeSample: seq[string]
    var sampleInit: bool = false

    for line in readme.lines:
      if sampleInit and not line.startsWith("```"):
        codeSample.add(line)
      if line.startsWith("```") and sampleInit:
        sampleInit = false

        # Write and test
        var testFilename = getRandomNimname()
        var output = open(testFilename, fmWrite)
        for line in codeSample:
          output.writeLine(line)
        output.close()

        var (outp, errC) = execCmdEx(&"nim c -d:release {testFilename}")
        doassert(errC == 0,
          &"Failed to compile Readme sample: {testFilename}\n{outp}")
        (outp, errC) = execCmdEx(&"./{testFilename.changeFileExt(\"\")}")
        doassert(errC == 0, &"Failed to execute Readme sample: {outp}")

        # Clear code sample and remove temp files
        codeSample = @[]
        removeFile(testFilename)
        removeFile(testFilename.changeFileExt(""))

      if line.startsWith("```nim"):
        sampleInit = true
