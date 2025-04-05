import value, instructions
import strformat
import math, tables
import strutils
import macros
import algorithm

macro generateFunctionMethods() {.used.} =
  result = quote do:
    proc registerFunction*(vm: RVM, name: string, fn: BytecodeFunction) =
      vm.functions[name] = fn

    proc getFunction*(vm: RVM, name: string): BytecodeFunction =
      if name in vm.functions:
        return vm.functions[name]
      return nil

type ModuleLoader* = ref object

type
  CallFrame* = object
    function*: BytecodeFunction
    pc*: int
    basePointer*: int  # Для доступа к локальным переменным
    argsOffset*: int

  RVM* = ref object
    stack*: seq[Value]
    globals*: Table[string, Value]
    locals*: seq[Value]
    currentFunction*: BytecodeFunction
    pc*: int
    running*: bool
    callStack*: seq[CallFrame]
    errorMessage*: string  # поле для хранения сообщения об ошибке
    hasError*: bool        # Флаг, указывающий на наличие ошибки
    functions*: Table[string, BytecodeFunction]  # Таблица функций
    moduleLoader*: ModuleLoader

generateFunctionMethods()

proc newRVM*(): RVM =
  result = RVM(
    stack: @[],
    globals: initTable[string, Value](),
    locals: @[],
    currentFunction: nil,
    pc: 0,
    running: false,
    callStack: @[],
    errorMessage: "",
    hasError: false,
    moduleLoader: nil,
    functions: initTable[string, BytecodeFunction]()
  )

proc setError*(vm: RVM, message: string) =
  vm.errorMessage = message
  vm.hasError = true
  vm.running = false  # Останавливаем выполнение при ошибке

proc execute*(vm: RVM, instruction: Instruction): bool =
  case instruction.opcode:
    of opPush:
      let constIndex = instruction.operands[0]
      let value = vm.currentFunction.constants[constIndex]
      vm.stack.add(value)
      echo "After opPush: stack=", vm.stack
      
    of opPop:
      if vm.stack.len == 0:
        echo "Error: Stack underflow"
        return false
      discard vm.stack.pop()
      
    of opDup:
      if vm.stack.len == 0:
        echo "Error: Stack underflow"
        return false
      let value = vm.stack[^1]
      vm.stack.add(value)
      
    of opSwap:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
      let a = vm.stack[^1]
      let b = vm.stack[^2]
      vm.stack[^1] = b
      vm.stack[^2] = a
      
    # Арифметические операции
    of opAdd:
      if vm.stack.len < 2:
        vm.setError("Stack underflow in opAdd")
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if isNumber(a) and isNumber(b):
        # Используем getNumberValue вместо прямого доступа к полю
        let res = getNumberValue(a) + getNumberValue(b)
        # Сохраняем тип результата (типизированный или нет)
        if a.kind == vkTypedNumber and b.kind == vkTypedNumber:
          vm.stack.add(newTypedNumber(res))
        else:
          vm.stack.add(newNumber(res))
      elif isString(a) and isString(b):
        let res = getStringValue(a) & getStringValue(b)
        if a.kind == vkTypedString and b.kind == vkTypedString:
          vm.stack.add(newTypedString(res))
        else:
          vm.stack.add(newString(res))
      else:
        vm.setError("Unsupported operand types for +")
        return false
        
    of opSub:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkNumber and b.kind == vkNumber:
        vm.stack.add(newNumber(a.numValue - b.numValue))
      else:
        echo "Error: Can only subtract numbers"
        return false
    
    of opMul:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkNumber and b.kind == vkNumber:
        vm.stack.add(newNumber(a.numValue * b.numValue))
      else:
        echo "Error: Can only multiply numbers"
        return false
    
    of opDiv:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkNumber and b.kind == vkNumber:
        if b.numValue == 0:
          echo "Error: Division by zero"
          return false
        vm.stack.add(newNumber(a.numValue / b.numValue))
      else:
        echo "Error: Can only divide numbers"
        return false

    of opTypedAdd:
      if vm.stack.len < 2:
        vm.setError("Stack underflow in opTypedAdd")
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      # Предполагаем, что компилятор уже проверил типы
      if a.kind == vkTypedNumber and b.kind == vkTypedNumber:
        vm.stack.add(newTypedNumber(a.numValue + b.numValue))
      elif a.kind == vkTypedString and b.kind == vkTypedString:
        vm.stack.add(newTypedString(a.strValue & b.strValue))
      else:
        vm.setError("Type mismatch in opTypedAdd")
        return false

    of opTypedSub:
      if vm.stack.len < 2:
        vm.setError("Stack underflow in opTypedSub")
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkTypedNumber and b.kind == vkTypedNumber:
        vm.stack.add(newTypedNumber(a.numValue - b.numValue))
      else:
        vm.setError("Type mismatch in opTypedSub, expected typed numbers")
        return false
      
      return true

    of opTypedMul:
      if vm.stack.len < 2:
        vm.setError("Stack underflow in opTypedMul")
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkTypedNumber and b.kind == vkTypedNumber:
        vm.stack.add(newTypedNumber(a.numValue * b.numValue))
      else:
        vm.setError("Type mismatch in opTypedMul, expected typed numbers")
        return false
      
      return true

    of opTypedDiv:
      if vm.stack.len < 2:
        vm.setError("Stack underflow in opTypedDiv")
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkTypedNumber and b.kind == vkTypedNumber:
        if b.numValue == 0:
          vm.setError("Division by zero")
          return false
        vm.stack.add(newTypedNumber(a.numValue / b.numValue))
      else:
        vm.setError("Type mismatch in opTypedDiv, expected typed numbers")
        return false
      
      return true

    of opMod:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
            
      let b = vm.stack.pop()
      let a = vm.stack.pop()
        
      if a.kind == vkNumber and b.kind == vkNumber:
        if b.numValue == 0:
          echo "Error: Modulo by zero"
          return false
        vm.stack.add(newNumber(floorMod(a.numValue, b.numValue)))
      else:
        echo "Error: Can only perform modulo on numbers"
        return false
    
    of opNeg:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let a = vm.stack.pop()
      
      if a.kind == vkNumber:
        vm.stack.add(newNumber(-a.numValue))
      else:
        echo "Error: Can only negate numbers"
        return false
    
    of opInc:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let a = vm.stack.pop()
      
      if a.kind == vkNumber:
        vm.stack.add(newNumber(a.numValue + 1))
      else:
        echo "Error: Can only increment numbers"
        return false
    
    of opDec:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let a = vm.stack.pop()
      
      if a.kind == vkNumber:
        vm.stack.add(newNumber(a.numValue - 1))
      else:
        echo "Error: Can only decrement numbers"
        return false
    
    # Логические операции
    of opEq:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == b.kind:
        case a.kind:
          of vkNumber:
            vm.stack.add(newBoolean(a.numValue == b.numValue))
          of vkBoolean:
            vm.stack.add(newBoolean(a.boolValue == b.boolValue))
          of vkString:
            vm.stack.add(newBoolean(a.strValue == b.strValue))
          else:
            vm.stack.add(newBoolean(false))
      else:
        vm.stack.add(newBoolean(false))
    
    of opNeq:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == b.kind:
        case a.kind:
          of vkNumber:
            vm.stack.add(newBoolean(a.numValue != b.numValue))
          of vkBoolean:
            vm.stack.add(newBoolean(a.boolValue != b.boolValue))
          of vkString:
            vm.stack.add(newBoolean(a.strValue != b.strValue))
          else:
            vm.stack.add(newBoolean(true))
      else:
        vm.stack.add(newBoolean(true))
    
    of opLt:
      if vm.stack.len < 2:
        vm.setError("Stack underflow in opLt")
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
    
      if a.kind in {vkNumber, vkTypedNumber} and b.kind in {vkNumber, vkTypedNumber}:
        vm.stack.add(newBoolean(a.numValue < b.numValue))
      else:
        vm.setError("Can only compare numbers")
        return false

    of opLte:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        vm.running = false
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind in {vkNumber, vkTypedNumber} and b.kind in {vkNumber, vkTypedNumber}:
        vm.stack.add(newBoolean(a.numValue <= b.numValue))
      else:
        echo "Error: Can only compare numbers"
        vm.running = false
        return false
    
    of opGt:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind in {vkNumber, vkTypedNumber} and b.kind in {vkNumber, vkTypedNumber}:
        vm.stack.add(newBoolean(a.numValue > b.numValue))
      else:
        echo "Error: Can only compare numbers"
        return false
    
    of opGte:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind in {vkNumber, vkTypedNumber} and b.kind in {vkNumber, vkTypedNumber}:
        vm.stack.add(newBoolean(a.numValue >= b.numValue))
      else:
        echo "Error: Can only compare numbers"
        return false
    
    of opAnd:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkBoolean and b.kind == vkBoolean:
        vm.stack.add(newBoolean(a.boolValue and b.boolValue))
      else:
        echo "Error: Can only perform logical AND on booleans"
        return false
    
    of opOr:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkBoolean and b.kind == vkBoolean:
        vm.stack.add(newBoolean(a.boolValue or b.boolValue))
      else:
        echo "Error: Can only perform logical OR on booleans"
        return false
    
    of opNot:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let a = vm.stack.pop()
      
      if a.kind in {vkBoolean, vkTypedBoolean}:
        vm.stack.add(newBoolean(not a.boolValue))
      else:
        echo "Error: Can only perform logical NOT on booleans"
        return false
    
    # Управление потоком выполнения
    of opJmp:
      let target = instruction.operands[0]
      if target >= 0 and target < vm.currentFunction.instructions.len:
        vm.pc = target
        return false  # Важно! Возвращаем false, чтобы не увеличивать PC
      else:
        vm.setError("Invalid jump target: " & $target)
        return false
    
    of opJz, opJnz:
      if vm.stack.len < 1:
        vm.setError("Stack underflow in conditional jump")
        return false
        
      let condition = vm.stack.pop()
      let target = instruction.operands[0]
      
      if target >= 0 and target < vm.currentFunction.instructions.len:
        if (instruction.opcode == opJz and not condition.boolValue) or
          (instruction.opcode == opJnz and condition.boolValue):
          vm.pc = target
      else:
        vm.setError("Invalid jump target: " & $target)
        return false
      
      return true
    
    # Работа с переменными
    of opLoad:
      let localIndex = instruction.operands[0]
      echo "Loading local at index: ", localIndex
      echo "Locals: ", vm.locals
      if instruction.labelRef.len > 0 and instruction.labelRef.startsWith("$"):
        let value = vm.locals[0] # Первый аргумент в locals[0]
        vm.stack.add(value)
      else:
        let localIndex = instruction.operands[0]
        vm.stack.add(vm.locals[localIndex])

    of opStore:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        vm.running = false
        return false  # Возвращаем false, но VM продолжает работу
        
      let localIndex = instruction.operands[0]
      
      if localIndex >= vm.locals.len:
        echo "Error: Local variable index out of bounds"
        vm.running = false
        return false
        
      vm.locals[localIndex] = vm.stack.pop()

    
    # Прочие операции
    of opPrint:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let value = vm.stack.pop()
      echo $value
    
    of opConcat:
      if vm.stack.len < 2:
        echo "Error: Stack underflow"
        return false
        
      let b = vm.stack.pop()
      let a = vm.stack.pop()
      
      if a.kind == vkString and b.kind == vkString:
        vm.stack.add(newString(a.strValue & b.strValue))
      else:
        echo "Error: Can only concatenate strings"
        return false
    
    of opLen:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let a = vm.stack.pop()
      
      case a.kind:
        of vkString:
          vm.stack.add(newNumber(a.strValue.len.float))
        of vkArray:
          vm.stack.add(newNumber(a.elements.len.float))
        else:
          echo "Error: Can only get length of strings and arrays"
          return false
    
    of opType:
      if vm.stack.len < 1:
        echo "Error: Stack underflow"
        return false
        
      let a = vm.stack[^1]  # Peek, don't pop
      
      case a.kind:
        of vkNull: vm.stack.add(newString("null"))
        of vkNumber, vkTypedNumber: vm.stack.add(newString("number"))
        of vkBoolean, vkTypedBoolean: vm.stack.add(newString("boolean"))
        of vkString, vkTypedString: vm.stack.add(newString("string"))
        of vkObject: vm.stack.add(newString("object"))
        of vkArray: vm.stack.add(newString("array"))
        of vkFunction: vm.stack.add(newString("function"))

    of opCall:
      echo "Calling function with args: ", instruction.operands[1]
      echo "Stack before call: ", vm.stack
      if vm.stack.len < instruction.operands[1]:
        vm.setError("Stack underflow in function call")
        return false
        
      let functionNameIndex = instruction.operands[0]
      let argCount = instruction.operands[1]
      
      if functionNameIndex >= vm.currentFunction.constants.len:
        vm.setError("Invalid function name index")
        return false
        
      let functionNameValue = vm.currentFunction.constants[functionNameIndex]
      if functionNameValue.kind != vkString:
        vm.setError("Function name must be a string")
        return false
        
      let functionName = functionNameValue.strValue
      
      # Get the function by name
      let function = vm.getFunction(functionName)
      if function == nil:
        vm.setError(fmt"Function '{functionName}' not found")
        return false
        
      # Save the current context
      vm.callStack.add(CallFrame(
        function: vm.currentFunction,
        pc: vm.pc + 1,
        basePointer: vm.locals.len - argCount # Important for accessing arguments
      ))
        
      # Copy arguments to the new function's locals
      var args: seq[Value] = @[]
      for i in 0..<argCount:
        if vm.stack.len > 0:
          args.add(vm.stack.pop())
        else:
          vm.setError("Stack underflow when popping arguments")
          return false
      
      # Reverse the arguments so the first argument is first in the list
      args.reverse()
      
      # Set up the new context
      vm.currentFunction = function
      vm.pc = 0
      
      # Create locals for the function
      vm.locals = newSeq[Value](function.localCount)
      for i in 0..<function.localCount:
        vm.locals[i] = newNull()
      
      # Copy arguments to the beginning of locals
      for i in 0..<min(argCount, function.localCount):
        vm.locals[i] = args[i]
      
      # Debug output
      echo "Function call: ", functionName
      echo "Arguments: ", args
      echo "Locals after copying arguments: ", vm.locals
        
      return false # Don't increment PC

    of opRet:
      let hasReturnValue = instruction.operands.len > 0 and instruction.operands[0] == 1
      var returnValue = newNull()
      
      if hasReturnValue and vm.stack.len > 0:
        returnValue = vm.stack.pop()
      
      # Восстанавливаем предыдущий контекст
      if vm.callStack.len > 0:
        let frame = vm.callStack.pop()
        vm.currentFunction = frame.function
        vm.pc = frame.pc + 1  # +1 чтобы перейти к следующей инструкции после вызова
        
        # Восстанавливаем локальные переменные
        vm.locals.setLen(frame.basePointer + vm.currentFunction.localCount)
        
        # Если есть возвращаемое значение, кладем его на стек
        if hasReturnValue:
          vm.stack.add(returnValue)
      else:
        # Это главная функция, завершаем выполнение
        vm.running = false
      
      return false  # Не увеличиваем PC

    of opHalt:
      vm.running = false
    
    # Пока не реализованные опкоды
    of opLoadGlobal, opStoreGlobal, 
       opNewArray, opGetItem, opSetItem, opNewObject, opGetField, opSetField:
      echo fmt"Error: Opcode {instruction.opcode} not implemented yet"
      return false
      
  return true

proc run*(vm: RVM, function: BytecodeFunction, isMainCode: bool = false): Value =
  vm.currentFunction = function
  vm.pc = 0
  vm.running = true
  vm.hasError = false
  vm.errorMessage = ""
  vm.locals = newSeq[Value](function.localCount)
  
  # Заполняем locals значениями null
  for i in 0..<function.localCount:
    vm.locals[i] = newNull()
  
  echo "Initial stack: ", vm.stack
  echo "Initial locals: ", vm.locals
  
  if isMainCode:
    echo "Running main code"
  else:
    echo "Running function: ", function.name
    echo "Param count: ", function.paramCount
    echo "Local count: ", function.localCount
  
  var iterations = 0
  while vm.running:
    iterations += 1
      
    if vm.pc >= vm.currentFunction.instructions.len:
      vm.running = false
      break
      
    let instruction = vm.currentFunction.instructions[vm.pc]
    
    # Отладочный вывод
    echo fmt"Executing {instruction.opcode} at PC={vm.pc}"
    
    let shouldIncrementPC = vm.execute(instruction)
    
    # Если произошла ошибка, прекращаем выполнение
    if vm.hasError:
      break
    
    # Увеличиваем PC только если инструкция не изменила его сама
    if shouldIncrementPC:
      vm.pc += 1
    
    # Отладочный вывод стека
    echo fmt"Stack: {vm.stack}"
  
  # Возвращаем результат или информацию об ошибке
  if vm.hasError:
    echo fmt"ERROR: {vm.errorMessage}"
    return newNull()  # Возвращаем null при ошибке
  elif vm.stack.len > 0:
    return vm.stack.pop()
  else:
    return newNull()

