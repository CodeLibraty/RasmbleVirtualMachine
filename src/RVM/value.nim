import tables

type
  ValueKind* = enum
    # динамические типы
    vkNull, vkNumber, vkBoolean, vkString, vkObject, vkArray, vkFunction,
    # Типизированные типы
    vkTypedNumber, vkTypedString, vkTypedBoolean


  Value* = ref object
    case kind*: ValueKind
    of vkNull:
      discard
    of vkObject:
      fields*: Table[string, Value]
    of vkArray:
      elements*: seq[Value]
    of vkFunction:
      funcIndex*: int
    of vkNumber, vkTypedNumber:
      numValue*: float
    of vkBoolean, vkTypedBoolean:
      boolValue*: bool
    of vkString, vkTypedString:
      strValue*: string
    
proc newNull*(): Value =
  result = Value(kind: vkNull)

proc newNumber*(value: float): Value =
  result = Value(kind: vkNumber, numValue: value)

proc newBoolean*(value: bool): Value =
  result = Value(kind: vkBoolean, boolValue: value)

proc newString*(value: string): Value =
  result = Value(kind: vkString, strValue: value)

proc newObject*(): Value =
  result = Value(kind: vkObject, fields: initTable[string, Value]())

proc newArray*(): Value =
  result = Value(kind: vkArray, elements: @[])

proc newFunction*(index: int): Value =
  result = Value(kind: vkFunction, funcIndex: index)

proc newTypedNumber*(value: float): Value =
  result = Value(kind: vkTypedNumber, numValue: value)

proc newTypedBoolean*(value: bool): Value =
  result = Value(kind: vkTypedBoolean, boolValue: value)

proc newTypedString*(value: string): Value =
  result = Value(kind: vkTypedString, strValue: value)



proc isNumber*(value: Value): bool =
  result = value.kind in {vkNumber, vkTypedNumber}

proc isBoolean*(value: Value): bool =
  result = value.kind in {vkBoolean, vkTypedBoolean}

proc isString*(value: Value): bool =
  result = value.kind in {vkString, vkTypedString}

proc getNumberValue*(value: Value): float =
  if value.kind in {vkNumber, vkTypedNumber}:
    result = value.numValue
  else:
    raise newException(ValueError, "Value is not a number")

proc getBooleanValue*(value: Value): bool =
  if value.kind in {vkBoolean, vkTypedBoolean}:
    result = value.boolValue
  else:
    raise newException(ValueError, "Value is not a boolean")

proc getStringValue*(value: Value): string =
  if value.kind in {vkString, vkTypedString}:
    result = value.strValue
  else:
    raise newException(ValueError, "Value is not a string")


proc `$`*(value: Value): string =
  case value.kind:
    of vkNull:
      result = "null"
    of vkNumber, vkTypedNumber:
      result = $value.numValue
    of vkBoolean, vkTypedBoolean:
      result = $value.boolValue
    of vkString, vkTypedString:
      result = value.strValue
    of vkObject:
      result = "{...}"  # Упрощенное представление объекта
    of vkArray:
      result = "[...]"  # Упрощенное представление массива
    of vkFunction:
      result = "function#" & $value.funcIndex