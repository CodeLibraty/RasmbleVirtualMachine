import value

type
  OpCode* = enum
    # Базовые операции со стеком
    opPush, opPop, opDup, opSwap,
    
    # Арифметические операции
    opAdd, opSub, opMul, opDiv, opMod, opNeg, opInc, opDec,
    
    # Логические операции
    opEq, opNeq, opLt, opLte, opGt, opGte, opAnd, opOr, opNot,
    
    # Управление потоком выполнения
    opJmp, opJz, opJnz, opCall, opRet,
    
    # Работа с переменными
    opLoad, opStore, opLoadGlobal, opStoreGlobal,
    
    # Работа с массивами и объектами
    opNewArray, opGetItem, opSetItem, opNewObject, opGetField, opSetField,
    
    # Типизированные опкоды
    opTypedAdd, opTypedSub, opTypedMul, opTypedDiv

    # Прочие операции
    opPrint, opConcat, opLen, opType, opHalt

  Instruction* = object
    opcode*: OpCode
    operands*: seq[int]
    labelRef*: string  # поле для хранения имени метки

  BytecodeFunction* = ref object
    name*: string
    instructions*: seq[Instruction]
    constants*: seq[Value]
    localCount*: int
    paramCount*: int
