"""Tüm testleri çalıştırır (WoW istemcisi gerekmez). Gereken: Python 3 ve `pip install lupa`.
Kullanım (depo kökünden ya da herhangi bir yerden):  python tools/run_tests.py [test_adı ...]
Örnek: python tools/run_tests.py roads map   -> yalnızca tests/roads.lua ve tests/map.lua"""
import glob
import os
import sys

from lupa.lua51 import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
wanted = set(sys.argv[1:])
ok = bad = 0
for path in sorted(glob.glob(os.path.join('tests', '*.lua'))):
    name = os.path.splitext(os.path.basename(path))[0]
    if wanted and name not in wanted:
        continue
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("table.unpack = table.unpack or unpack")
    # testler os.exit çağırabilir: başarı kodu hata sayılmasın
    lua.execute("function os.exit(c) if c and c ~= 0 and c ~= true then error('os.exit('..tostring(c)..')', 0) end error('__EXIT_OK__', 0) end")
    try:
        lua.execute(open(path, encoding='utf-8').read())
        ok += 1
        print('OK  ', path)
    except Exception as e:
        message = str(e)
        if '__EXIT_OK__' in message:
            ok += 1
            print('OK  ', path)
        else:
            bad += 1
            print('FAIL', path, '->', message[:300].replace('\n', ' | '))
print('\n%d geçti, %d başarısız' % (ok, bad))
sys.exit(1 if bad else 0)
