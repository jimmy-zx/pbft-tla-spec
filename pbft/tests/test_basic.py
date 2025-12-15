import tempfile
import os
import subprocess
import re
import pathlib

import pytest
import run


BASE_MODEL = "model.cfg"
LIVENESS_CONFIG = "liveness.cfg"

COUNT_PATTERN = re.compile(
    r"^([\d]+) states generated, "
    r"([\d]+) distinct states found, 0 states left on queue\.$",
    re.M,
)
PATH_PATTERN = re.compile(r"^(Path_([a-zA-Z0-9]*)_[a-zA-Z0-9]+) ==", re.M)
CONSTANT = re.compile(r"^CONSTANT ([^\s]+) = (.*)$")


PATH_TESTCASES: list[tuple[str, str]] = []


os.chdir(pathlib.Path(__file__).parent.parent)


def init_test():
    with open("model.tla", "r") as fp:
        matches = PATH_PATTERN.findall(fp.read())
        global PATH_TESTCASES
        PATH_TESTCASES = matches


init_test()


PROFILES: list[tuple[str, dict, bool]] = [
    ("base", {}, False),
    ("view1", {"View0": "{1}"}, False),
    ("stage2", {"MaxPrimarySeq": "4"}, False),
    ("stage3", {"MaxPrimarySeq": "5"}, True),
]


def base_config() -> str:
    with open(BASE_MODEL, "r") as fp:
        return fp.read()


def liveness_config() -> str:
    with open(LIVENESS_CONFIG, "r") as fp:
        return fp.read()


def add_invariant(base: str, inv: str) -> str:
    return base + f"\nINVARIANT {inv}"


def override_constants(base: str, configs: dict[str, str]) -> str:
    base = "\\* overridden over\n" + base
    lines = base.split("\n")
    for i, line in enumerate(lines):
        m = CONSTANT.match(line)
        if m:
            key, _ = m.groups()
            if key in configs:
                lines[i] = f"CONSTANT {key} = {configs[key]}"
    return "\n".join(lines)


def run_with_tmp_config(config: str) -> subprocess.CompletedProcess:
    with tempfile.NamedTemporaryFile(mode="wb", buffering=0, suffix=".cfg") as cfg_fp:
        cfg_fp.write(config.encode())
        return run.run(cfg_fp.name, no_trace=False)


def validate_states(name: str, p: subprocess.CompletedProcess) -> None:
    assert p.stdout is not None
    assert (m := COUNT_PATTERN.search(p.stdout)) is not None
    count_file = f"./data/{name}.out"
    if os.path.isfile(count_file):
        with open(count_file, "r") as fp:
            assert m.group() == fp.read()
    with open(count_file, "w") as fp:
        fp.write(m.group())


@pytest.mark.parametrize("invariant, profile", PATH_TESTCASES)
def test_path_reachable(invariant: str, profile: str) -> None:
    overrides = [override for name, override, _ in PROFILES if name == profile][0]
    p = run_with_tmp_config(
        add_invariant(override_constants(base_config(), overrides), invariant)
    )
    assert p.returncode != 0
    assert f"Invariant {invariant} is violated" in p.stdout


@pytest.mark.parametrize(
    "name, override, slow",
    PROFILES,
)
def test_profile(name: str, override: dict[str, str], slow: bool, request) -> None:
    if slow and not request.config.getoption("--run-slow"):
        pytest.skip()
    config = override_constants(base_config(), override)
    with open(f"./data/{name}.cfg", "w") as fp:
        fp.write(config)
    p = run_with_tmp_config(config)
    assert p.returncode == 0
    validate_states(name, p)


@pytest.mark.parametrize(
    "name, override, slow",
    PROFILES,
)
def test_liveness(name: str, override: dict[str, str], slow: bool, request) -> None:
    _ = slow
    if not request.config.getoption("--run-slow"):
        pytest.skip()
    override |= {"SymNodes": "{}"}
    config = override_constants(base_config(), override)
    config = config + "\n" + liveness_config()
    with open(f"./data/{name}_liveness.cfg", "w") as fp:
        fp.write(config)
    p = run_with_tmp_config(config)
    assert p.returncode == 0
    validate_states(f"{name}_liveness", p)
