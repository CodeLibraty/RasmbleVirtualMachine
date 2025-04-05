#!/bin/bash

# Функция для вывода справки
show_help() {
    echo "Скрипт для компиляции RytonVM под различные платформы"
    echo "Использование: $0 [опции]"
    echo ""
    echo "Опции:"
    echo "  -p, --platform PLATFORM   Целевая платформа (linux, windows, macos)"
    echo "  -h, --help                Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 -p linux               Компиляция под Linux"
    echo "  $0 -p windows             Компиляция под Windows"
    echo "  $0 -p macos               Компиляция под macOS"
    echo ""
}

# Проверка наличия Nim
if ! command -v nim &> /dev/null; then
    echo "Ошибка: Nim не установлен. Пожалуйста, установите Nim."
    exit 1
fi

# Проверка наличия аргументов
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Парсинг аргументов
PLATFORM=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--platform)
            PLATFORM="$2"
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
done

# Проверка выбранной платформы
if [ -z "$PLATFORM" ]; then
    echo "Ошибка: Не указана целевая платформа."
    show_help
    exit 1
fi

# Создание директории для бинарных файлов
mkdir -p bin

# Компиляция в зависимости от выбранной платформы
case $PLATFORM in
    linux)
        echo "Компиляция под Linux..."
        nim c -d:release -d:linux src/main.nim

        # Проверка успешности компиляции
        if [ $? -eq 0 ]; then
            echo "Компиляция успешно завершена. Исполняемый файл: bin/RVM"

            # Создание дистрибутива
            mkdir -p dist/linux
            cp RVM dist/linux/
            cp -r examples dist/linux/ 2>/dev/null || echo "Директория examples не найдена"
            echo "Ryton Virtual Machine (RVM) - Rasmble Bytecode Interpreter" > dist/linux/README.txt

            echo "Дистрибутив создан в директории dist/linux/"
        else
            echo "Ошибка при компиляции."
            exit 1
        fi
        ;;

    windows)
        echo "Компиляция под Windows..."

        # Проверка наличия MinGW
        if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
            echo "Ошибка: MinGW не установлен. Пожалуйста, установите mingw-w64."
            echo "sudo apt-get install mingw-w64"
            exit 1
        fi

        nim c --os:windows --cpu:amd64 --cc:gcc --gcc.exe:x86_64-w64-mingw32-gcc --gcc.linkerexe:x86_64-w64-mingw32-gcc src/main.nim

        # Проверка успешности компиляции
        if [ $? -eq 0 ]; then
            echo "Компиляция успешно завершена. Исполняемый файл: RVM.exe"

            # Создание дистрибутива
            mkdir -p dist/windows
            cp RVM.exe dist/windows/
            cp -r examples dist/windows/ 2>/dev/null || echo "Директория examples не найдена"
            echo "Ryton Virtual Machine (RVM) - Rasmble Bytecode Interpreter" > dist/windows/README.txt

            # Создание ZIP-архива
            cd dist
            zip -r RytonVM-windows-x64.zip windows/
            cd ..

            echo "Дистрибутив создан в директории dist/windows/"
            echo "ZIP-архив: dist/RVM-windows-x64.zip"
        else
            echo "Ошибка при компиляции."
            exit 1
        fi
        ;;

    macos)
        echo "Компиляция под macOS..."

        # Для кросс-компиляции под macOS может потребоваться дополнительная настройка
        # Здесь предполагается, что вы компилируете на macOS
        nim c -d:release -d:macosx src/main.nim

        # Проверка успешности компиляции
        if [ $? -eq 0 ]; then
            echo "Компиляция успешно завершена. Исполняемый файл: RVM"

            # Создание дистрибутива
            mkdir -p dist/macos
            mv RVM dist/macos/
            cp -r examples dist/macos/ 2>/dev/null || echo "Директория examples не найдена"
            echo "Ryton Virtual Machine (RVM) - Rasmble Bytecode Interpreter" > dist/macos/README.txt

            # Создание DMG-образа (требуется hdiutil, доступен только на macOS)
            if command -v hdiutil &> /dev/null; then
                hdiutil create -volname "RVM" -srcfolder dist/macos -ov -format UDZO dist/RytonVM-macos.dmg
                echo "DMG-образ создан: dist/RVM-macos.dmg"
            else
                echo "Утилита hdiutil не найдена, DMG-образ не создан."
            fi

            echo "Дистрибутив создан в директории dist/macos/"
        else
            echo "Ошибка при компиляции."
            exit 1
        fi
        ;;

    *)
        echo "Ошибка: Неизвестная платформа '$PLATFORM'."
        echo "Поддерживаемые платформы: linux(posix), windows(win32), macos(darwin)"
        exit 1
        ;;
esac

echo "Готово!"
exit 0
