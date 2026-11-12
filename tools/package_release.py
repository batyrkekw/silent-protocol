"""Validate the standalone Windows executable, including its embedded Godot pack."""
from pathlib import Path
import struct, plistlib, subprocess, hashlib, json, shutil, zipfile
root = Path(__file__).resolve().parents[1]
exe = root.parent / 'SilentProtocol.exe'
blob = exe.read_bytes()
assert blob[:2] == b'MZ', 'Missing Windows PE executable'
pe = struct.unpack_from('<I', blob, 0x3c)[0]
assert blob[pe:pe+4] == b'PE\0\0', 'Invalid PE header'
assert struct.unpack_from('<H', blob, pe+4)[0] == 0x8664, 'Expected x86_64'
assert blob[-4:] == b'GDPC', 'Missing embedded Godot pack footer'
pack_size = struct.unpack_from('<Q', blob, len(blob)-12)[0]
start = len(blob)-12-pack_size
assert 0 < start < len(blob)-12, 'Invalid embedded pack length'
assert blob[start:start+4] == b'GDPC', 'Missing embedded Godot pack header'
print(f'Validated standalone Windows executable: {exe} ({len(blob)/1024/1024:.1f} MiB)')

app=root.parent/'Silent Protocol.app'
info=plistlib.loads((app/'Contents/Info.plist').read_bytes())
mac_binary=app/'Contents/MacOS'/info['CFBundleExecutable']
assert mac_binary.is_file() and mac_binary.stat().st_mode & 0o111
assert (app/'Contents/Resources/SilentProtocol.pck').is_file()
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict',str(app)],check=True)
manifest={'windows_exe_sha256':hashlib.sha256(blob).hexdigest(),
          'mac_binary_sha256':hashlib.sha256(mac_binary.read_bytes()).hexdigest(),
          'mac_pack_sha256':hashlib.sha256((app/'Contents/Resources/SilentProtocol.pck').read_bytes()).hexdigest()}
(root/'design/release_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
destination=root/'build/windows/SilentProtocol.exe'
destination.parent.mkdir(parents=True,exist_ok=True)
shutil.copy2(exe,destination)
archive=root.parent/'SilentProtocol-Windows-x64.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as package:
    package.write(exe,'SilentProtocol/SilentProtocol.exe')
    package.writestr('SilentProtocol/START_HERE.txt', 'Silent Protocol — САНА\n\nWindows 10/11 x64: полностью распакуйте архив и откройте SilentProtocol.exe.\nGodot и дополнительные программы не нужны. Игра работает без интернета.\n\nПеретаскивайте команды из нижней палитры. ▶ запускает программу; ключ возвращает к плану.\nНачните с обучения. Язык и звук — вверху.\n\nhttps://github.com/batyrkekw/silent-protocol\n')
    package.write(root/'third_party.md','SilentProtocol/third_party.md')
with zipfile.ZipFile(archive) as package:
    assert package.testzip() is None
    assert hashlib.sha256(package.read('SilentProtocol/SilentProtocol.exe')).hexdigest()==manifest['windows_exe_sha256']
print(f'Windows build copied into repository: {destination}')
print(f'Windows ZIP verified: {archive}')
