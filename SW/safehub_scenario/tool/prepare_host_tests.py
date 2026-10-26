"""Prepare all scenario production sources/tests in a disposable host project."""

import argparse
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE.parent / "wifi_sensing"))
from prepare_ui_tests import prepare


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New/empty directory outside the checkout")
    args = parser.parse_args()
    try:
        count = prepare(SOURCE, args.output, full=True)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Prepared scenario host: {args.output.resolve()} ({count} files)")


if __name__ == "__main__":
    main()
