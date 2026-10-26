"""Probe real fastText APIs, optionally an explicitly supplied existing model.

Never trains/replaces a model or starts a service. HTTP/model validation remains
separate; without --model this only checks the installed native runtime API.
"""
import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model', type=Path)
    args = parser.parse_args()
    import fasttext
    import numpy

    assert fasttext.tokenize('화재 안내') == ['화재', '안내']
    report = {
        'python': sys.version.split()[0],
        'fasttext': importlib.metadata.version('fasttext'),
        'numpy': numpy.__version__,
        'native_tokenize': 'passed',
        'real_model_validation': 'not_run: model unconfirmed/unavailable',
        'real_model_http': 'not_run',
    }
    if args.model is not None:
        # Fail rather than silently substituting a toy model.
        model = fasttext.load_model(str(args.model))
        sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
        from classifier import FireTextClassifier
        report['model_sha256'] = hashlib.sha256(args.model.read_bytes()).hexdigest()
        report['labels'] = model.get_labels()
        report['classification'] = FireTextClassifier(model).classify('화재가 발생했습니다. 대피하세요.')
        report['real_model_validation'] = 'load/predict passed; not an accuracy measurement'
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
