import RVM/core, RVM/value, RVM/instructions
import RVM/function_manager, RVM/macro_processor
import os, strutils, tables
import RSM_Parser

proc runFromFile(filename: string, debug: bool = false) =
  if not fileExists(filename):
    echo "Error: File not found: ", filename
    return
  
  let function = parseFile(filename)
  
  if debug:
    echo "Disassembled bytecode:"
    echo disassemble(function)
    echo ""
  
  let vm = newRVM()
  let result = vm.run(function)
  
  echo "Execution completed"
  echo "Result: ", result

proc runExample() =
  let bytecode = createExampleBytecode()
  
  # Сохраняем во временный файл
  let tempFile = "example.rbc"
  writeFile(tempFile, bytecode)
  
  echo "Running example bytecode:"
  runFromFile(tempFile, true)
  
  # Удаляем временный файл
  removeFile(tempFile)

proc showHelp() =
  echo "RVM - Ryton Virtual Machine"
  echo "Usage:"
  echo "  rvm [options] <filename>"
  echo ""
  echo "Options:"
  echo "  -d, --debug    Enable debug output"
  echo "  -e, --example  Run example bytecode"
  echo "  -h, --help     Show this help message"

proc notmain() =
  var 
    filename = ""
    debug = false
    runExample = false
  
  # Обработка аргументов командной строки
  for i in 1..paramCount():
    let arg = paramStr(i)
    if arg == "-d" or arg == "--debug":
      debug = true
    elif arg == "-e" or arg == "--example":
      runExample = true
    elif arg == "-h" or arg == "--help":
      showHelp()
      return
    else:
      filename = arg
  
  if runExample:
    runExample()
    return
  
  if filename == "":
    showHelp()
    return
  
  runFromFile(filename, debug)

proc main() =
  # Создаем процессор макросов
  let macroProcessor = newMacroProcessor()

  if paramCount() == 0:
    showHelp()
    return
    
  var 
    filename = ""
    debug = false
  
  # Обработка аргументов
  for i in 1..paramCount():
    let arg = paramStr(i)
    if arg == "-d" or arg == "--debug":
      debug = true
    elif arg == "-h" or arg == "--help":
      showHelp()
      return
    else:
      filename = arg
  
  if filename == "":
    showHelp()
    return
  
  # Читаем и выполняем код из файла
  let code = readFile(filename)
  

  # Обрабатываем макросы в коде
  let expandedCode = macroProcessor.expandMacros(code)
  echo "Expanded code:"
  echo expandedCode

  # Парсим код
  let parser = newBytecodeParser()
  let mainFunction = parser.parse(expandedCode)
  
  # Создаем VM
  let vm = newRVM()
  
  # Регистрируем все процедуры в VM
  echo "Registering procedures in VM:"
  for name, procDef in tables.pairs(parser.procs):
    # Сохраняем текущее состояние парсера
    let savedLabels = parser.labels
    let savedInstructions = parser.instructions
    let savedConstants = parser.constants
    let savedFunctionName = parser.functionName
    let savedLocalCount = parser.localCount
    
    # Устанавливаем состояние для парсинга процедуры
    parser.labels.clear()
    parser.instructions = @[]
    parser.functionName = name
    parser.localCount = procDef.localCount
    
    # Создаем новый парсер для каждой процедуры
    let procParser = newBytecodeParser()
    
    # Парсим только тело процедуры
    let procCode = procDef.body.join("\n")
    echo "Parsing procedure body for ", name, ":\n", procCode
    
    # Устанавливаем имя функции и количество локальных переменных
    procParser.functionName = name
    procParser.localCount = procDef.localCount
    
    # Парсим тело процедуры
    let function = procParser.parse(procCode, true)
    
    # Регистрируем функцию в VM
    vm.registerFunction(name, function)
    echo "  Registered function in VM: ", name
    
    # Восстанавливаем состояние парсера
    parser.labels = savedLabels
    parser.instructions = savedInstructions
    parser.constants = savedConstants
    parser.functionName = savedFunctionName
    parser.localCount = savedLocalCount
  
  # Выводим все зарегистрированные функции
  echo "Functions registered in VM:"
  for name, _ in vm.functions:
    echo "  ", name
  
  # Запускаем main
  discard vm.run(mainFunction, true)

when isMainModule:
  main()
