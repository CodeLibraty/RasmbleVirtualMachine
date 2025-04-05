import macros

macro generateFunctionManager*() =
  result = quote do:
    proc registerFunction*(vm: RVM, name: string, fn: BytecodeFunction) =
      vm.functions[name] = fn

    proc getFunction*(vm: RVM, name: string): BytecodeFunction =
      if name in vm.functions:
        return vm.functions[name]
      return nil