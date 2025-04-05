import json, strutils
import value, instructions

proc loadBytecodeFromFile*(filename: string): BytecodeFunction =
  let jsonData = parseFile(filename)
  
  # Загружаем константы
  var constants: seq[Value] = @[]
  for constItem in jsonData["constants"]:
    let constType = constItem["type"].getStr()
    case constType:
      of "number":
        constants.add(newNumber(constItem["value"].getFloat()))
      of "string":
        constants.add(newString(constItem["value"].getStr()))
      of "boolean":
        constants.add(newBoolean(constItem["value"].getBool()))
      of "null":
        constants.add(newNull())
      else:
        echo "Unknown constant type: ", constType
  
  # Загружаем инструкции
  var instructions: seq[Instruction] = @[]
  for instrItem in jsonData["instructions"]:
    let opcodeStr = instrItem["opcode"].getStr()
    let opcode = parseEnum[OpCode]("op" & opcodeStr)
    
    var operands: seq[int] = @[]
    for operand in instrItem["operands"]:
      operands.add(operand.getInt())
      
    instructions.add(Instruction(opcode: opcode, operands: operands))
  
  # Создаем функцию
  result = BytecodeFunction(
    name: jsonData["name"].getStr(),
    instructions: instructions,
    constants: constants,
    localCount: jsonData["localCount"].getInt()
  )
