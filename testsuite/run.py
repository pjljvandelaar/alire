#! /usr/bin/env python

"""
e3.testsuite-based testsuite for Alire/ALR.

Just execute this script to run the testsuite. It requires a Python 3
interpreter with the e3-core and e3-testsuite packages (from PyPI) installed.
"""

from __future__ import absolute_import, print_function

import sys
import os.path

import e3.testsuite
import e3.testsuite.driver
from e3.testsuite.result import TestStatus


from drivers.python_script import PythonScriptDriver


class Testsuite(e3.testsuite.Testsuite):
    tests_subdir = 'tests'
    test_driver_map = {'python-script': PythonScriptDriver}

    def set_up(self):
        super().set_up()

        # Some tests rely on an initially empty GPR_PROJECT_PATH variable
        os.environ.pop('GPR_PROJECT_PATH', None)

        # Let's run `alr` from project's dir
        alr_path = self._get_alr_path()
        self._prepend_alr_to_path_env_var(alr_path)

    def _get_alr_path(self):
        project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(project_root, 'bin')

    def _prepend_alr_to_path_env_var(self, alr_path):
        os.environ['PATH'] = alr_path + os.pathsep + os.environ['PATH']

if __name__ == '__main__':
    suite = Testsuite()
    sys.exit(suite.testsuite_main(sys.argv[1:] + ["--failure-exit-code=1"]))
