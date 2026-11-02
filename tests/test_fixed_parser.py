"""Check the fixed parser against the five required input cases."""

import pathlib
import subprocess
import sys
import tempfile


def main():
    binary = pathlib.Path(sys.argv[1]).resolve()
    project = pathlib.Path(__file__).resolve().parent.parent
    with tempfile.TemporaryDirectory() as directory:
        root = pathlib.Path(directory)

        def run(*args):
            return subprocess.run(
                [str(binary), *map(str, args)], cwd=root,
                capture_output=True, timeout=5,
            )

        def check_accepted(name, path, data):
            result = run(path)
            assert result.returncode == 0, (name, result)
            assert result.stdout == data[:32] + b"\n", (name, result)
            assert not result.stderr, (name, result)
            print(f"PASS: {name}")

        def check_rejected(name, path):
            result = run(path)
            assert result.returncode == 1, (name, result)
            assert not result.stdout, (name, result)
            assert b"128-byte limit" in result.stderr, (name, result)
            assert not (root / "markers").exists(), name
            print(f"PASS: {name}")

        short_path = project / "tests" / "short.log"
        check_accepted("valid short input", short_path, short_path.read_bytes())

        for size in (128, 129):
            data = b"A" * size
            path = root / f"input_{size}.log"
            path.write_bytes(data)
            if size == 128:
                check_accepted("exactly maximum allowed input", path, data)
            else:
                check_rejected("one byte over the limit", path)

        missing = root / "missing.log"
        result = run(missing)
        assert result.returncode == 1, ("missing file", result)
        assert not result.stdout, ("missing file", result)
        assert str(missing).encode() in result.stderr, ("missing file", result)
        print("PASS: missing file")

        # Run the original generator in isolation so its payload stays in the
        # temporary directory and its offset/address are not duplicated here.
        (root / "inbox").mkdir()
        subprocess.run(
            [sys.executable, str(project / "src" / "make_payload.py")],
            cwd=root, capture_output=True, check=True, timeout=5,
        )
        check_rejected("original exploit payload", root / "inbox" / "payload.bin")

    print("All 5 cases passed")


if __name__ == "__main__":
    main()
