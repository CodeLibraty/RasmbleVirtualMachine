import os, strutils
import macro_processor

type
  MacroLoader* = ref object
    searchPaths*: seq[string]
    macroProcessor*: MacroProcessor

proc newMacroLoader*(macroProcessor: MacroProcessor): MacroLoader =
  result = MacroLoader(
    searchPaths: @["./stdlib/macros", "./"],
    macroProcessor: macroProcessor
  )

proc addSearchPath*(loader: MacroLoader, path: string) =
  loader.searchPaths.add(path)

proc findMacroFile*(loader: MacroLoader, fileName: string): string =
  for path in loader.searchPaths:
    let fullPath = path / fileName
    if fileExists(fullPath):
      return fullPath
  return ""

proc loadMacroFile*(loader: MacroLoader, fileName: string): bool =
  let filePath = loader.findMacroFile(fileName)
  if filePath == "":
    echo "Error: Macro file not found: ", fileName
    return false

  let macroCode = readFile(filePath)
  var inMacroDefinition = false
  var currentMacroName = ""
  var currentMacroParams: seq[string] = @[]
  var currentMacroBody: seq[string] = @[]

  for line in macroCode.splitLines():
    let trimmedLine = line.strip()
    
    if trimmedLine.startsWith(".macro "):
      inMacroDefinition = true
      let parts = trimmedLine[7..^1].split()
      currentMacroName = parts[0]
      currentMacroParams = parts[1..^1]
      currentMacroBody = @[]
      
    elif trimmedLine.startsWith(".end macro "):
      if inMacroDefinition:
        loader.macroProcessor.defineMacro(currentMacroName, currentMacroParams, currentMacroBody)
        echo "Loaded macro: ", currentMacroName
      inMacroDefinition = false
      
    elif inMacroDefinition and trimmedLine != "":
      currentMacroBody.add(trimmedLine)

  return true
