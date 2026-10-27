#!/usr/bin/env bash
# Host development dependency setup only; does not install/restart a device service.
set -euo pipefail
component_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <venv-directory-outside-checkout>" >&2
  exit 2
fi
venv_dir=$(realpath -m -- "$1")
repo_dir=$(git -C "$component_dir" rev-parse --show-toplevel)
case "$venv_dir/" in "$repo_dir/"*) echo "Keep the venv outside the checkout" >&2; exit 2;; esac
command -v gcc >/dev/null
command -v g++ >/dev/null
command -v uv >/dev/null
python3 -c 'import sys; assert sys.version_info[:2] == (3, 12), "Host setup requires Python 3.12"'
if [ ! -x "$venv_dir/bin/python" ]; then
  uv venv --python python3 "$venv_dir"
fi
# This Python distribution names clang++ in sysconfig, but that executable is
# unavailable here. Select installed GCC explicitly for fastText's C++17 build.
CC=gcc CXX=g++ uv pip install --python "$venv_dir/bin/python" -r "$component_dir/requirements.txt"
uv pip check --python "$venv_dir/bin/python"
"$venv_dir/bin/python" "$component_dir/tools/check_runtime.py"
