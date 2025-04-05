import instructions, core, function_manager, ../RSM_Parser
import tables, os, strformat, strutils

type
  Module* = ref object
    name*: string
    functions*: Table[string, BytecodeFunction]
    exports*: seq[string]  # Имена экспортируемых функций

  ModuleLoader* = ref object
    vm*: RVM
    functionManager*: FunctionManager
    modules*: Table[string, Module]
    searchPaths*: seq[string]

proc newModule*(name: string): Module =
  result = Module(
    name: name,
    functions: initTable[string, BytecodeFunction](),
    exports: @[]
  )

proc addFunction*(module: Module, function: BytecodeFunction) =
  module.functions[function.name] = function

proc exportFunction*(module: Module, functionName: string) =
  if functionName in module.functions:
    if functionName notin module.exports:
      module.exports.add(functionName)
  else:
    echo fmt"Warning: Cannot export non-existent function '{functionName}'"

proc getExportedFunctions*(module: Module): Table[string, BytecodeFunction] =
  result = initTable[string, BytecodeFunction]()
  for name in module.exports:
    result[name] = module.functions[name]

proc newModuleLoader*(vm: RVM, functionManager: FunctionManager): ModuleLoader =
  result = ModuleLoader(
    vm: vm,
    functionManager: functionManager,
    modules: initTable[string, Module](),
    searchPaths: @[".", "./modules", "./lib"]
  )

proc addSearchPath*(loader: ModuleLoader, path: string) =
  if path notin loader.searchPaths:
    loader.searchPaths.add(path)

proc findModuleFile*(loader: ModuleLoader, moduleName: string): string =
  for path in loader.searchPaths:
    let filePath = path / moduleName & ".rasm"
    if fileExists(filePath):
      return filePath
  return ""

proc callModuleFunction*(loader: ModuleLoader, moduleName: string, functionName: string, args: seq[Value]): Value =
  # Проверяем, загружен ли модуль
  if moduleName notin loader.modules:
    echo fmt"Error: Module '{moduleName}' not loaded"
    return newNull()
  
  let module = loader.modules[moduleName]
  
  # Проверяем, существует ли функция в модуле
  let fullFunctionName = moduleName & "." & functionName
  
  # Проверяем, экспортирована ли функция
  if functionName notin module.functions or functionName notin module.exports:
    echo fmt"Error: Function '{functionName}' not found in module '{moduleName}' or not exported"
    return newNull()
  
  let function = module.functions[functionName]
  
  # Вызываем функцию через FunctionManager
  return loader.functionManager.callFunction(fullFunctionName, args)

proc loadModule*(loader: ModuleLoader, moduleName: string): Module =
  # Проверяем, не загружен ли уже модуль
  if moduleName in loader.modules:
    return loader.modules[moduleName]
  
  # Ищем файл модуля
  let filePath = loader.findModuleFile(moduleName)
  if filePath == "":
    echo fmt"Error: Module '{moduleName}' not found in search paths"
    return nil
  
  # Создаем новый модуль
  var module = newModule(moduleName)
  
  # Читаем и парсим файл модуля
  let code = readFile(filePath)
  let lines = code.splitLines()
  
  var currentFunction: BytecodeFunction = nil
  var inFunction = false
  var functionCode = ""
  
  for line in lines:
    let trimmedLine = line.strip()
    
    if trimmedLine.startsWith(".module "):
      # Проверяем, что имя модуля совпадает
      let moduleDeclName = trimmedLine[8..^1].strip()
      if moduleDeclName != moduleName:
        echo fmt"Warning: Module name mismatch: expected '{moduleName}', found '{moduleDeclName}'"
    
    elif trimmedLine.startsWith(".export "):
      # Экспортируем функцию
      let functionName = trimmedLine[8..^1].strip()
      module.exportFunction(functionName)
    
    elif trimmedLine.startsWith(".function "):
      # Начало новой функции
      if inFunction:
        # Парсим предыдущую функцию
        let parser = newBytecodeParser()
        currentFunction = parser.parse(functionCode)
        module.addFunction(currentFunction)
        functionCode = ""
      
      inFunction = true
      functionCode = line & "\n"
    
    elif inFunction:
      # Добавляем строку к коду функции
      functionCode &= line & "\n"
  
  # Парсим последнюю функцию, если она есть
  if inFunction and functionCode != "":
    let parser = newBytecodeParser()
    currentFunction = parser.parse(functionCode)
    module.addFunction(currentFunction)
  
  # Регистрируем экспортируемые функции в менеджере функций
  for name, function in module.getExportedFunctions():
    loader.functionManager.registerFunction(function)
  
  # Сохраняем модуль
  loader.modules[moduleName] = module
  
  return module

proc importModule*(loader: ModuleLoader, moduleName: string): bool =
  let module = loader.loadModule(moduleName)
  return module != nil
