import os
import pathlib
import subprocess


os.chdir(pathlib.Path(__file__).parent.parent)


def test_flake8():
    subprocess.check_output(["flake8", "."])


def test_pylint():
    subprocess.check_output(["pylint", "."])


def test_mypy():
    subprocess.check_output(["mypy", "."])


def test_black():
    subprocess.check_output(["black", "--check", "."])
