import re

from importlib import resources


def read_requirements(filepath):
    """
    Read packages requirements from file
    """

    with open(filepath, 'r', encoding='utf8') as file:
        lines = file.read().split('\n')

    packages = list(filter(re.compile(r"^[^#\n\s]").match, lines))

    return packages


def read_module_requirements(package, requirements):
    """
    Read requirements from module file
    """

    with resources.open_text(package, requirements) as file:
        lines = file.read().split('\n')

    packages = list(filter(re.compile(r"^[^#\n\s]").match, lines))

    return packages
