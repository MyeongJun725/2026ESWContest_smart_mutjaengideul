"""Prepare all scenario production sources/tests in a disposable host project."""

import argparse
from pathlib import Path

from host_support import prepare

SOURCE = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="New/empty directory outside the checkout")
    args = parser.parse_args()
    try:
        count = prepare(SOURCE, args.output)
    except (OSError, ValueError) as error:
        parser.error(str(error))
    print(f"Prepared scenario host: {args.output.resolve()} ({count} files)")


if __name__ == "__main__":
    main()
