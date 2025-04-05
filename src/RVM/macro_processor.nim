import tables, strutils, sequtils

type
  RasmbleMacro* = object
    name*: string
    params*: seq[string]
    body*: seq[string]

  MacroProcessor* = ref object
    macros*: Table[string, RasmbleMacro]

proc newMacroProcessor*(): MacroProcessor =
  result = MacroProcessor(
    macros: initTable[string, RasmbleMacro]()
  )

proc defineMacro*(processor: MacroProcessor, name: string, params: seq[string], body: seq[string]) =
  var rasmbleMacro = RasmbleMacro(
    name: name,
    params: params,
    body: body
  )
  processor.macros[name] = rasmbleMacro

proc expandMacro*(processor: MacroProcessor, name: string, args: seq[string]): seq[string] =
  if name notin processor.macros:
    echo "Error: Macro not found: ", name
    return @[]
    
  let rasmbleMacro = processor.macros[name]
  
  if args.len != rasmbleMacro.params.len:
    echo "Error: Macro ", name, " expects ", rasmbleMacro.params.len, " arguments, but got ", args.len
    return @[]
  
  var expandedLines: seq[string] = @[]
  
  # Заменяем параметры в теле макроса
  for line in rasmbleMacro.body:
    var expandedLine = line
    for i in 0..<rasmbleMacro.params.len:
      # Используем явную замену строк
      let paramName = "$" & rasmbleMacro.params[i]
      let paramValue = args[i]
      echo "Replacing ", paramName, " with ", paramValue, " in line: ", expandedLine
      expandedLine = expandedLine.replace(paramName, paramValue)
      echo "After replacement: ", expandedLine
    expandedLines.add(expandedLine)
  
  echo "Expanded macro lines:"
  for line in expandedLines:
    echo line
    
  return expandedLines

proc expandMacros*(processor: MacroProcessor, code: string): string =
  var lines = code.splitLines()
  var resultLines: seq[string] = @[]  # Изменено имя переменной с result на resultLines
  
  for line in lines:
    if line.strip().startsWith("@"):
      # Это вызов макроса
      let macroCall = line.strip()[1..^1]  # Убираем символ @
      let openParen = macroCall.find('(')
      let closeParen = macroCall.rfind(')')
      
      if openParen == -1 or closeParen == -1:
        echo "Error: Invalid macro call syntax: ", line
        resultLines.add(line)
        continue
      
      let macroName = macroCall[0..<openParen].strip()
      let argsStr = macroCall[openParen+1..<closeParen].strip()
      
      # Разбираем аргументы
      var args: seq[string] = @[]
      for arg in argsStr.split(','):
        args.add(arg.strip())
      
      # Расширяем макрос
      let expandedLines = processor.expandMacro(macroName, args)
      
      if expandedLines.len == 0:
        # Макрос не найден или ошибка
        resultLines.add(line)
      else:
        # Добавляем расширенные строки
        for expandedLine in expandedLines:
          resultLines.add(expandedLine)
    else:
      # Обычная строка
      resultLines.add(line)
  
  return resultLines.join("\n")

proc processMacros*(processor: MacroProcessor, code: string): string =
  var lines = code.splitLines()
  var processedLines: seq[string] = @[]
  var i = 0
  
  # Сначала обрабатываем определения макросов
  while i < lines.len:
    let line = lines[i].strip()
    
    if line.startsWith(".macro "):
      let parts = line[7..^1].strip().split(" ")
      if parts.len < 1:
        echo "Error: Invalid macro definition"
        i += 1
        continue
        
      let macroName = parts[0]
      var params: seq[string] = @[]
      
      if parts.len > 1 and parts[1].startsWith("(") and parts[^1].endsWith(")"):
        let paramStr = parts[1..^1].join(" ")
        let paramList = paramStr[1..^2].strip()  # Убираем скобки
        params = paramList.split(",").mapIt(it.strip())
      
      var body: seq[string] = @[]
      i += 1
      
      # Собираем тело макроса до .endmacro
      while i < lines.len and not lines[i].strip().startsWith(".endmacro"):
        body.add(lines[i])
        i += 1
      
      if i < lines.len:  # Пропускаем .endmacro
        i += 1
      
      processor.defineMacro(macroName, params, body)
    else:
      processedLines.add(line)
      i += 1
  
  # Теперь обрабатываем вызовы макросов
  var finalLines: seq[string] = @[]
  for line in processedLines:
    if line.contains("@"):  # Маркер вызова макроса
      let parts = line.split("@", 1)
      let prefix = parts[0]
      let macroCall = parts[1]
      
      let callParts = macroCall.split("(", 1)
      if callParts.len < 2:
        echo "Error: Invalid macro call: ", line
        finalLines.add(line)
        continue
        
      let macroName = callParts[0].strip()
      var argsStr = callParts[1]
      
      if not argsStr.endsWith(")"):
        echo "Error: Invalid macro call, missing closing parenthesis: ", line
        finalLines.add(line)
        continue
        
      argsStr = argsStr[0..^2]  # Убираем закрывающую скобку
      
      var args: seq[string] = @[]
      var currentArg = ""
      var inString = false
      var depth = 0
      
      for c in argsStr:
        if c == '"':
          inString = not inString
          currentArg.add(c)
        elif c == '(' and not inString:
          depth += 1
          currentArg.add(c)
        elif c == ')' and not inString:
          depth -= 1
          currentArg.add(c)
        elif c == ',' and not inString and depth == 0:
          args.add(currentArg.strip())
          currentArg = ""
        else:
          currentArg.add(c)
      
      if currentArg.len > 0:
        args.add(currentArg.strip())
      
      let expanded = processor.expandMacro(macroName, args)
      for expLine in expanded:
        finalLines.add(prefix & expLine)
    else:
      finalLines.add(line)
  
  return finalLines.join("\n")
