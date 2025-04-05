# Общие настройки для всех платформ
switch("opt", "speed")
switch("d", "release")
switch("threads", "on")
switch("outdir", "bin")

# Настройки для конкретных платформ
when defined(windows):
  # Настройки для Windows
  switch("cc", "gcc")
  switch("gcc.exe", "x86_64-w64-mingw32-gcc")
  switch("gcc.linkerexe", "x86_64-w64-mingw32-gcc")
  switch("os", "windows")
  
  # Статическая линковка для независимости от DLL
  switch("passL", "-static")
  
  # Дополнительные оптимизации
  switch("passC", "-flto")
  switch("passL", "-flto")
  
  # Отключаем консольное окно для GUI-приложений
  # Раскомментируйте следующую строку, если это GUI-приложение
  # switch("app", "gui")
  
  # Имя выходного файла
  switch("out", "RVM.exe")

when defined(linux):
  # Настройки для Linux
  switch("cc", "gcc")
  
  # Оптимизации для Linux
  switch("passC", "-flto -march=native")
  switch("passL", "-flto -s")
  
  # Статическая линковка для Linux (по желанию)
  # switch("passL", "-static")
  
  # Имя выходного файла
  switch("out", "RVM")

when defined(macosx):
  # Настройки для macOS
  switch("cc", "clang")
  
  # Оптимизации для macOS
  switch("passC", "-flto")
  switch("passL", "-flto")
  
  # Имя выходного файла
  switch("out", "RVM")
