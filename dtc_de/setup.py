import glob
import re

from setuptools import setup, find_packages


def read_requirements(file_path):
    with open(file_path, "r") as file:
        lines = file.read().split("\n")

    packages = list(filter(re.compile(r"^[^#\n\s]").match, lines))
    return packages


def get_extras_require():
    """
    Get extras_require setup dictionary based on requirements.EXTRA.txt files

    Example output:
        {'extract_load_trips_from_tlc_to_gs': ['aiofiles==23.1.0', 'aiohttp==3.8.4', 'google-cloud-storage==2.8.0']}
    """
    extras_requirements = glob.glob("./requirements.*.txt")
    extra_name_exp = re.compile(r"requirements\.(.*)\.txt")

    def get_name(extra_req):
        name = extra_name_exp.search(extra_req).group(1)
        return name

    extras_require = {get_name(ex): read_requirements(ex)
                      for ex in extras_requirements}
    return extras_require


setup(
    name="dtc_de",
    packages=find_packages(include=["dtc_de", "dtc_de.*"]),
    version="0.1.0",
    extras_require=get_extras_require(),
)
