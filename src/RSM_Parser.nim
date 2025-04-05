import tables, strutils
import RVM/value         # Импортируем модуль с определением Value
import RVM/instructions  # Импортируем модуль с определением VM и опкодов
import RVM/macro_processor
import RVM/macro_loader

type
  ProcDefinition = object
    name*: string
    params*: seq[string]
    body*: seq[string]
    localCount*: int
    paramNames*: seq[string]

  BytecodeParser* = ref object
    labels*: Table[string, int]  # Таблица меток и их адресов
    constants*: seq[Value]       # Таблица констант
    instructions*: seq[Instruction]  # Сгенерированные инструкции
    functionName*: string        # Имя функции
    localCount*: int             # Количество локальных переменных
    imports*: seq[string]
    macroProcessor*: MacroProcessor
    macroLoader*: MacroLoader
    procs*: Table[string, ProcDefinition]
    procStack: seq[string]
    currentProc*: string

proc newBytecodeParser*(): BytecodeParser =
  result = BytecodeParser(
    labels: initTable[string, int](),
    constants: @[],
    instructions: @[],
    functionName: "<ROOT>",
    localCount: 0,
    imports: @[],
    macroProcessor: newMacroProcessor()
  )
  result.macroLoader = newMacroLoader(result.macroProcessor)


proc findOrAddConstant(parser: BytecodeParser, value: Value): int =
  # Ищем константу в существующем списке
  for i, constVal in parser.constants:
    if constVal.kind == value.kind:
      case constVal.kind
      of vkNumber, vkTypedNumber:
        if constVal.numValue == value.numValue:
          return i
      of vkBoolean, vkTypedBoolean:
        if constVal.boolValue == value.boolValue:
          return i
      of vkString, vkTypedString:
        if constVal.strValue == value.strValue:
          return i
      of vkObject, vkArray, vkFunction, vkNull:
        discard  # Эти типы сравниваем по ссылке или не сравниваем
  
  # Если не нашли, добавляем новую константу
  result = parser.constants.len
  parser.constants.add(value)

proc parseNumber(parser: BytecodeParser, token: string, typed: bool = false): int =
  # Преобразуем строку в число и добавляем его как константу
  let value = parseFloat(token)
  if typed:
    result = parser.findOrAddConstant(newTypedNumber(value))
  else:
    result = parser.findOrAddConstant(newNumber(value))

proc parseBoolean(parser: BytecodeParser, token: string, typed: bool = false): int =
  # Преобразуем строку в булево значение и добавляем его как константу
  let value = token.toLowerAscii() == "true"
  if typed:
    result = parser.findOrAddConstant(newTypedBoolean(value))
  else:
    result = parser.findOrAddConstant(newBoolean(value))

proc parseString(parser: BytecodeParser, token: string, typed: bool = false): int =
  # Удаляем кавычки и добавляем строку как константу
  let value = token[1..^2]  # Убираем кавычки
  if typed:
    result = parser.findOrAddConstant(newTypedString(value))
  else:
    result = parser.findOrAddConstant(newString(value))

proc resolveLabels(parser: BytecodeParser) =
  # Заменяем метки на адреса в инструкциях перехода
  for i, instr in parser.instructions:
    case instr.opcode
    of opJmp, opJz, opJnz:
      let operand = instr.operands[0]
      if operand < 0:  # Отрицательный операнд означает ссылку на метку
        let labelIndex = -operand - 1
        let labelName = $labelIndex
        if labelName in parser.labels:
          parser.instructions[i].operands[0] = parser.labels[labelName]
        else:
          echo "Error: Undefined label: ", labelName
    else:
      discard

proc findAndRegisterProcs*(parser: BytecodeParser, code: string): string =
  echo "findAngRegisterProcs is starting"
  
  var lines = code.splitLines()
  var cleanedLines: seq[string] = @[]
  var i = 0
  
  while i < lines.len:
    let line = lines[i].strip()
    
    if line.startsWith(".proc "):
      # Нашли начало процедуры
      let parts = line[6..^1].strip().split()
      let procName = parts[0]
      echo "Proc Name find: ", procName
      
      var params: seq[string] = @[]
      if parts.len > 1:
        params = parts[1..^1]
      echo "params: ", params
      
      # Собираем тело процедуры
      var procBody: seq[string] = @[]
      var j = i + 1
      var localCount = 0
      
      while j < lines.len and not lines[j].strip().startsWith(".end proc"):
        let bodyLine = lines[j].strip()
        echo "finded ending proc, line: ", bodyLine
        
        # Проверяем наличие локальных переменных
        if bodyLine.startsWith(".locals "):
          let localParts = bodyLine.split()
          if localParts.len > 1:
            try:
              localCount = parseInt(localParts[1])
              echo "Found locals: ", localCount
            except:
              echo "Error parsing locals count"
        
        # Добавляем строку в тело процедуры
        procBody.add(lines[j])
        j += 1
      
      # Проверяем, что нашли конец процедуры
      if j < lines.len and lines[j].strip().startsWith(".end proc"):
        # Регистрируем процедуру
        var procDef = ProcDefinition(
          name: procName,
          params: params,
          body: procBody,  # Здесь должно быть тело процедуры
          localCount: localCount
        )
        parser.procs[procName] = procDef
        echo "Registered procedure: ", procName, " with body length: ", procBody.len
        
        # Пропускаем все строки процедуры, включая .end proc
        i = j + 1
      else:
        echo "Error: Missing .end proc for procedure ", procName
        cleanedLines.add(lines[i])
        i += 1
    else:
      cleanedLines.add(lines[i])
      i += 1
  
  # Выводим очищенный код для отладки
  echo "Cleaned code after removing procedures:"
  for line in cleanedLines:
    echo line
  
  # Возвращаем код без определений процедур
  return cleanedLines.join("\n")

proc parse*(parser: BytecodeParser, code: string, isProcBody: bool = false): BytecodeFunction =
  if isProcBody == false:
    # Очищаем состояние парсера перед началом
    parser.labels.clear()  # Убедимся, что таблица меток пуста
    parser.instructions = @[]
    parser.constants = @[]
    parser.functionName = "<ROOT>"  # Значение по умолчанию
    parser.localCount = 0  # Значение по умолчанию
    parser.imports = @[]
    
  let code = parser.findAndRegisterProcs(code)
  var lines = code.splitLines()
  var currentInstructionIndex = 0
  
  if parser.macroProcessor == nil:
    parser.macroProcessor = newMacroProcessor()

  # Первый проход: собираем метки и директивы
  for lineNum, line in lines:
    # Удаляем комментарии и лишние пробелы
    let commentPos = line.find('#')
    let cleanLine = if commentPos >= 0: line[0..<commentPos].strip() else: line.strip()
    
    if cleanLine.len == 0:
      continue
    
    if cleanLine.startsWith(".label "):
      let labelName = cleanLine[7..^1].strip()
      # Сохраняем текущий индекс инструкции для этой метки
      parser.labels[labelName] = currentInstructionIndex
      echo "Found label: ", labelName, " at address ", currentInstructionIndex, " (line ", lineNum + 1, ")"
    elif cleanLine.startsWith(".function "):
      parser.functionName = cleanLine[10..^1].strip()
      echo "Found function: ", parser.functionName
    elif cleanLine.startsWith(".locals "):
      parser.localCount = parseInt(cleanLine[8..^1].strip())
      echo "Found locals: ", parser.localCount
    elif line.startsWith(".import "):
      let moduleName = line[8..^1].strip()
      parser.imports.add(moduleName)
    elif line.startsWith(".include "):
      let macroFile = line[9..^1].strip().replace("\"", "")
      if macroFile.endsWith(".macro"):
        if not parser.macroLoader.loadMacroFile(macroFile):
          echo "Error loading macro file: ", macroFile
    elif not (cleanLine.startsWith(".") or cleanLine.len == 0):
      # Это инструкция, увеличиваем счетчик
      currentInstructionIndex += 1
    elif line.startsWith(".macro "):
      # Начало определения макроса
      let macroDefParts = line[7..^1].split()
      var i = 0
      if macroDefParts.len < 2:
        echo "Error: Invalid macro definition syntax: ", line
        i += 1
        continue
      
      let macroName = macroDefParts[0]
      let macroParams = macroDefParts[1..^1]
      var macroBody: seq[string] = @[]
      
      # Читаем тело макроса до .end macro
      i += 1
      while i < lines.len:
        let macroLine = lines[i].strip()
        if macroLine.startsWith(".end macro "):
          let endMacroName = macroLine[11..^1].strip()
          if endMacroName != macroName:
            echo "Error: Macro end name mismatch: ", macroName, " vs ", endMacroName
          break
        
        # Пропускаем комментарии
        if not macroLine.startsWith("#") and macroLine != "":
          macroBody.add(macroLine)
        
        i += 1
      
      # Регистрируем макрос
      echo "Registered macro: ", macroName, " with params: ", macroParams
      parser.macroProcessor.defineMacro(macroName, macroParams, macroBody)

  # Выводим все найденные метки
  echo "Labels found:"
  for labelName, address in parser.labels:
    echo labelName, " -> ", address
  
  # Если меток нет, выводим предупреждение
  if parser.labels.len == 0:
    echo "WARNING: No labels found in the code!"
  
  # Второй проход: генерируем инструкции
  # Сначала расширяем макросы
  let expandedCode = parser.macroProcessor.expandMacros(code)
  echo "Expanded code after macro processing:"
  echo expandedCode

  # Удаляем определения макросов из расширенного кода
  var cleanedLines: seq[string] = @[]
  var i = 0
  var inMacroDefinition = false

  for line in expandedCode.splitLines():
    let trimmedLine = line.strip()
    
    if trimmedLine.startsWith(".macro "):
      inMacroDefinition = true
      continue
    
    if trimmedLine.startsWith(".end macro "):
      inMacroDefinition = false
      continue
    
    if not inMacroDefinition:
      cleanedLines.add(line)

  let cleanedCode = cleanedLines.join("\n")
  echo "Cleaned code after removing macro definitions:"
  echo cleanedCode

  # Затем парсим очищенный код
  lines = cleanedCode.splitLines()

  # Затем парсим расширенный код
  for line in lines:
    # Удаляем комментарии и лишние пробелы
    let commentPos = line.find('#')
    let cleanLine = if commentPos >= 0: line[0..<commentPos].strip() else: line.strip()
    
    if cleanLine.len == 0 or cleanLine.startsWith("."):
      continue
    
    let tokens = cleanLine.splitWhitespace()
    if tokens.len == 0:
      continue
    
    let opname = tokens[0].toLowerAscii()
    
    case opname
    of "push":
      if tokens.len < 2:
        echo "Error: push requires an operand"
        continue
      
      let operand = tokens[1]
      var constIndex: int
      let isTyped = tokens.len > 2 and tokens[2] == "typed"
      
      if operand.startsWith("\"") and operand.endsWith("\""):
        constIndex = parser.parseString(operand, isTyped)
      elif operand == "true" or operand == "false":
        constIndex = parser.parseBoolean(operand, isTyped)
      else:
        try:
          constIndex = parser.parseNumber(operand, isTyped)
        except ValueError:
          echo "Error: Invalid constant: ", operand
          continue
      
      parser.instructions.add(Instruction(opcode: opPush, operands: @[constIndex]))
    
    of "load":
      if tokens.len < 2: continue
      let operand = tokens[1]
      
      if operand.startsWith("$"):
        let paramName = operand[1..^1]
        
        # Проверяем, что мы внутри процедуры
        if parser.currentProc != "":
          # Получаем определение текущей процедуры
          let procDef = parser.procs[parser.currentProc]
          
          # Ищем индекс параметра в списке параметров
          var paramIndex = -1
          for i, param in procDef.params:
            if param == paramName:
              paramIndex = i
              break
          
          if paramIndex >= 0:
            # Найден параметр - создаем инструкцию с правильным индексом
            parser.instructions.add(Instruction(
              opcode: opLoad,
              operands: @[paramIndex]  # Используем индекс параметра
            ))
          else:
            echo "Error: Parameter not found: ", paramName
        else:
          echo "Error: Parameter reference outside of procedure: ", operand
      else:
        # Обычная локальная переменная
        try:
          let localIndex = parseInt(operand)
          parser.instructions.add(Instruction(
            opcode: opLoad,
            operands: @[localIndex]
          ))
        except ValueError:
          echo "Error: Invalid local variable index: ", operand

    of "store":
      if tokens.len < 2:
        echo "Error: store requires an operand"
        continue
      
      let localIndex = parseInt(tokens[1])
      parser.instructions.add(Instruction(opcode: opStore, operands: @[localIndex]))
    
    # Арифметические операции
    of "add": parser.instructions.add(Instruction(opcode: opAdd, operands: @[]))
    of "sub": parser.instructions.add(Instruction(opcode: opSub, operands: @[]))
    of "mul": parser.instructions.add(Instruction(opcode: opMul, operands: @[]))
    of "div": parser.instructions.add(Instruction(opcode: opDiv, operands: @[]))
    
    # Типизированные арифметические операции
    of "typed_add": parser.instructions.add(Instruction(opcode: opTypedAdd, operands: @[]))
    of "typed_sub": parser.instructions.add(Instruction(opcode: opTypedSub, operands: @[]))
    of "typed_mul": parser.instructions.add(Instruction(opcode: opTypedMul, operands: @[]))
    of "typed_div": parser.instructions.add(Instruction(opcode: opTypedDiv, operands: @[]))
    
    # Операции сравнения
    of "lt": parser.instructions.add(Instruction(opcode: opLt, operands: @[]))
    of "gt": parser.instructions.add(Instruction(opcode: opGt, operands: @[]))
    of "eq": parser.instructions.add(Instruction(opcode: opEq, operands: @[]))
    of "ne": parser.instructions.add(Instruction(opcode: opNeq, operands: @[]))
    of "le": parser.instructions.add(Instruction(opcode: opLte, operands: @[]))
    of "ge": parser.instructions.add(Instruction(opcode: opGte, operands: @[]))
    
    # Операции перехода
    of "jmp", "jz", "jnz":
      if tokens.len < 2:
        echo "Error: ", opname, " requires a label"
        continue
      
      let labelName = tokens[1]
      # Временно сохраняем имя метки как строку в операнде
      # Позже заменим на адрес
      
      var opcode: OpCode
      if opname == "jmp": opcode = opJmp
      elif opname == "jz": opcode = opJz
      else: opcode = opJnz
      
      # Используем специальное значение для меток, которые будут разрешены позже
      parser.instructions.add(Instruction(opcode: opcode, operands: @[-1], labelRef: labelName))
    
    # Другие операции
    of "call":
      if tokens.len < 2:
        echo "Error: call requires a function name"
        var i = 0
        i += 1
        continue
      
      let functionName = strip(tokens[1], chars = {'"'}) 
      let constIndex = parser.constants.len
      parser.constants.add(newString(functionName))
      
      # Проверяем, является ли это вызовом функции из модуля
      if "." in functionName:
        # Это вызов функции из модуля (например, "math.max")
        let parts = functionName.split(".")
        let moduleName = parts[0]
        let funcName = parts[1]
        
        # Добавляем модуль в список импортов, если его там еще нет
        if moduleName notin parser.imports:
          parser.imports.add(moduleName)
      
      let argCount = if tokens.len > 2: parseInt(tokens[2]) else: 0
      parser.instructions.add(Instruction(opcode: opCall, operands: @[constIndex, argCount]))
    
    of "ret": parser.instructions.add(Instruction(opcode: opRet, operands: @[]))
    of "print": parser.instructions.add(Instruction(opcode: opPrint, operands: @[]))
    of "halt": parser.instructions.add(Instruction(opcode: opHalt, operands: @[]))
    
    else:
      echo "Error: Unknown instruction: ", opname
  
    # Разрешаем метки
    for i in 0..<parser.instructions.len:
      let instr = parser.instructions[i]
      if instr.opcode in {opJmp, opJz, opJnz} and instr.labelRef != "":
        if instr.labelRef in parser.labels:
          parser.instructions[i].operands[0] = parser.labels[instr.labelRef]
        else:
          echo "Error: Undefined label: ", instr.labelRef
          # Вместо -1 используем безопасное значение, например, 0
          parser.instructions[i].operands[0] = 0
  
  # Создаем функцию байткода
  result = BytecodeFunction(
    name: parser.functionName,
    instructions: parser.instructions,
    constants: parser.constants,
    localCount: parser.localCount
  )

proc parseFile*(filename: string): BytecodeFunction =
  let parser = newBytecodeParser()
  let code = readFile(filename)
  result = parser.parse(code)

# Функция для дизассемблирования байткода
proc disassemble*(function: BytecodeFunction): string =
  result = ".function " & function.name & "\n"
  result &= ".locals " & $function.localCount & "\n\n"
  
  # Создаем обратную таблицу меток (адрес -> имя метки)
  var labels: Table[int, string]
  
  # Сначала находим все адреса, на которые есть переходы
  for i, instr in function.instructions:
    case instr.opcode
    of opJmp, opJz, opJnz:
      let target = instr.operands[0]
      if target notin labels:
        labels[target] = "label_" & $target
    else:
      discard
  
  # Выводим инструкции с метками
  for i, instr in function.instructions:
    # Если есть метка для этого адреса, выводим ее
    if i in labels:
      result &= "\n.label " & labels[i] & "\n"
    
    # Выводим инструкцию
    result &= $i & ":\t"
    
    case instr.opcode
    of opPush:
      let constIndex = instr.operands[0]
      let constValue = function.constants[constIndex]
      result &= "push " & $constValue
      
      # Добавляем информацию о типе
      case constValue.kind
      of vkTypedNumber:
        result &= " typed"
      of vkTypedBoolean:
        result &= " typed"
      of vkTypedString:
        result &= " typed"
      else:
        discard
    
    of opLoad:
      result &= "load " & $instr.operands[0]
    
    of opStore:
      result &= "store " & $instr.operands[0]
    
    of opAdd:
      result &= "add"
    
    of opSub:
      result &= "sub"
    
    of opMul:
      result &= "mul"
    
    of opDiv:
      result &= "div"
    
    of opTypedAdd:
      result &= "typed_add"
    
    of opTypedSub:
      result &= "typed_sub"
    
    of opTypedMul:
      result &= "typed_mul"
    
    of opTypedDiv:
      result &= "typed_div"
    
    of opLt:
      result &= "lt"
    
    of opGt:
      result &= "gt"
    
    of opEq:
      result &= "eq"
    
    of opNeq:
      result &= "ne"
    
    of opLte:
      result &= "le"
    
    of opGte:
      result &= "ge"
    
    of opJmp:
      let target = instr.operands[0]
      if target in labels:
        result &= "jmp " & labels[target]
      else:
        result &= "jmp " & $target
    
    of opJz:
      let target = instr.operands[0]
      if target in labels:
        result &= "jz " & labels[target]
      else:
        result &= "jz " & $target
    
    of opJnz:
      let target = instr.operands[0]
      if target in labels:
        result &= "jnz " & labels[target]
      else:
        result &= "jnz " & $target
    
    of opCall:
      result &= "call " & $instr.operands[0]
    
    of opRet:
      result &= "ret"
    
    of opPrint:
      result &= "print"
    
    of opHalt:
      result &= "halt"
    
    else:
      result &= "unknown " & $instr.opcode
    
    result &= "\n"
  
  return result

# Функция для создания примера байткода для тестирования
proc createExampleBytecode*(): string =
  result = """
# Пример программы для сложения двух типизированных чисел в цикле
.function typedAddLoop
.locals 2  # sum, i

# Инициализация переменных
push 0 typed  # Типизированный ноль
store 0       # sum = 0

push 0 typed  # Типизированный ноль
store 1       # i = 0

.label loop
# Проверка условия: i < 99
load 1        # Загружаем i
push 99 typed # Загружаем типизированное 99
lt            # i < 99
jz end        # Если i >= 99, выходим из цикла

# Тело цикла: sum = sum + 2
load 0        # Загружаем sum
push 2 typed  # Загружаем типизированное 2
typed_add     # Типизированное сложение
store 0       # Сохраняем результат в sum

# i = i + 1
load 1        # Загружаем i
push 1 typed  # Загружаем типизированное 1
typed_add     # Типизированное сложение
store 1       # Сохраняем результат в i

# Печатаем текущее значение sum для отладки
load 0
print

jmp loop      # Возвращаемся в начало цикла

.label end
# Загружаем результат на стек перед завершением
load 0
halt
"""
