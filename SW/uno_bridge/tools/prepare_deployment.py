"""Dry-run/stage source files only. Never installs units or contacts devices."""
import argparse
from pathlib import Path
import hashlib
import json
import shutil
ROOT = Path(__file__).resolve().parents[3]
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,help='New empty staging directory; omitted prints plan only')
    args=parser.parse_args()
    mapping={}
    for directory,target in [('SW/uno_bridge','data/safehub-uno/app'),('SW/fasttext_context','data/safehub/fasttext/app'),('SW/rpi5_hub','data/safehub-sign-control/app/hub')]:
        for p in (ROOT/directory).rglob('*.py'):
            if 'tests' not in p.parts and 'tools' not in p.parts:
                mapping[str(p.relative_to(ROOT))]=str(Path(target)/p.relative_to(ROOT/directory))
    mapping['SW/uno_bridge/sign_hub.py']='data/safehub-sign-control/app/sign_hub.py'
    for directory in ('SW/uno_bridge','SW/fasttext_context'):
        for p in (ROOT/directory).glob('*.service'):
            mapping[str(p.relative_to(ROOT))]='data/share/usr/lib/systemd/system/'+p.name
    print(json.dumps(mapping,indent=2))
    if args.output is None:return
    output=args.output.resolve()
    if output.exists() or output==ROOT or ROOT in output.parents:
        parser.error('output must be a new directory outside the checkout')
    output.mkdir(parents=True)
    manifest={}
    for source,target in mapping.items():
        dest=output/target;dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(ROOT/source,dest)
        manifest[target]=hashlib.sha256(dest.read_bytes()).hexdigest()
    (output/'SOURCE_SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
if __name__=='__main__':main()
