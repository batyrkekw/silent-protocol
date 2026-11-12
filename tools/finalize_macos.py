"""Normalize the bundle executable name before signing (Unicode names break sealing)."""
from pathlib import Path
import plistlib, shutil, subprocess
root=Path(__file__).resolve().parents[1]
app=root.parent/'Silent Protocol.app'
contents=app/'Contents'
info_path=contents/'Info.plist'
info=plistlib.loads(info_path.read_bytes())
old=info['CFBundleExecutable']
if old!='SilentProtocol':
    (contents/'MacOS'/old).rename(contents/'MacOS/SilentProtocol')
    (contents/'Resources'/(old+'.pck')).rename(contents/'Resources/SilentProtocol.pck')
info['CFBundleExecutable']='SilentProtocol'
info['CFBundleName']='Silent Protocol'
info_path.write_bytes(plistlib.dumps(info))
signature=contents/'_CodeSignature'
if signature.exists():shutil.rmtree(signature)
(contents/'MacOS/SilentProtocol').chmod(0o755)
subprocess.run(['/usr/bin/codesign','--force','--deep','--sign','-',str(app)],check=True)
subprocess.run(['/usr/bin/codesign','--verify','--deep','--strict','--verbose=2',str(app)],check=True)
print('Signed and verified',app)
