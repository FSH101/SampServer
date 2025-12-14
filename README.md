# SampServer

## VGBD распаковщик для Windows

В каталоге [`tools`](tools) добавлен скрипт `unpack_decode_vgbd.py`, который расшифровывает (XOR) и распаковывает VGBD `.img`, содержащие Zstandard кадры. Можно работать как через консоль, так и через небольшое GUI на Tkinter.

### Использование CLI

```bash
python tools/unpack_decode_vgbd.py encrypted.img -o out_dir
python tools/unpack_decode_vgbd.py --list encrypted.img
```

Ключи:
- `--keep-paths` — сохранить исходные подпапки из архива (с безопасной проверкой путей).
- `--decoded-out <file>` — дополнительно сохранить расшифрованный контейнер.

### GUI и сборка .exe

```bash
python tools/unpack_decode_vgbd.py --gui
```

Для удобства конечных пользователей на Windows можно собрать единый `.exe` (PyInstaller требуется в системе):

```bash
pip install zstandard pyinstaller
pyinstaller --onefile --noconsole tools/unpack_decode_vgbd.py
```

Флаг `--noconsole` оставляет только окно GUI; если нужны логи консоли, можно его убрать. Готовый файл появится в `dist/unpack_decode_vgbd.exe`.