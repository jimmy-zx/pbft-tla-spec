#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess

PREFIX = "\\* M: "
XFAIL_PREFIX = "XFAIL: "
N_WORKERS = (os.cpu_count() or 2) // 2


def run(
    config: str, j: int = N_WORKERS, no_trace: bool = False
) -> subprocess.CompletedProcess:
    xfail: bytes | None = None
    with open(config, "r") as f:
        for line in f:
            line = line.strip()
            if line.startswith(PREFIX):
                line = line.removeprefix(PREFIX)
                if line.startswith(XFAIL_PREFIX):
                    assert xfail is None
                    xfail = line.removeprefix(XFAIL_PREFIX).encode()

    args = [
        "java",
        "-XX:+UseParallelGC",
        "tlc2.TLC",
        "-config",
        config,
        "-workers",
        str(j),
    ]

    if no_trace:
        args += ["-noTE"]

    args += ["model.tla"]

    with subprocess.Popen(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    ) as p:
        stdout: list[str] = []

        assert p.stdout is not None
        for line in p.stdout:
            stdout.append(line)
            sys.stdout.write(line)
            sys.stdout.flush()

        p.wait()

        return subprocess.CompletedProcess(p.args, p.returncode, "".join(stdout), None)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("profile", type=str)
    parser.add_argument("-j", type=int, default=N_WORKERS)
    args = parser.parse_args()

    config = args.profile
    p = run(config, args.j)

    assert p.returncode == 0


if __name__ == "__main__":
    main()
