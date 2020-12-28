#!/usr/bin/env python
"""
CodeChecker Bazel build & test wrapper script
"""

from __future__ import print_function
import getpass
import logging
import multiprocessing
import os
import re
import shlex
import subprocess


VERBOSITY = "{Verbosity}"
CODECHECKER_PATH = "{codecheckerPATH}"
CODECHECKER_SKIPFILE = "{codechecker_skipfile}"
CODECHECKER_FILES = "{codechecker_files}"
CODECHECKER_LOG = "{codechecker_log}"
COMPILE_COMMANDS = "{compile_commands}"


def fail(message, exit_code=1):
    """ Print error message and return exit code """
    logging.error(message)
    print()
    print("*" * 50)
    print("codechecker script execution FAILED!")
    if log_file_name():
        print("See: %s" % log_file_name())
        print("*" * 50)
        try:
            with open(log_file_name()) as log_file:
                print(log_file.read())
        except IOError:
            print("File not accessible")
    else:
        print(message)
    print("*" * 50)
    print()
    exit(exit_code)


def separator(method="info"):
    """ Print log separator line to logging.info() or other logging methods """
    getattr(logging, method)("#" * 23)


def stage(title, method="info"):
    """ Print stage title into log """
    separator(method)
    getattr(logging, method)("### " + title)
    separator(method)


def valid_parameter(parameter):
    """ Check if external parameter is defined and valid """
    if parameter is None:
        return False
    elif parameter and parameter[0] == "{":
        return False
    return True


def log_file_name():
    """ Check and return log file name """
    if valid_parameter(CODECHECKER_LOG):
        return CODECHECKER_LOG
    return None


def setup():
    """ Setup logging parameters for execution session """
    if VERBOSITY == "INFO":
        log_level = logging.INFO
    elif VERBOSITY == "WARN":
        log_level = logging.WARN
    else:
        log_level = logging.DEBUG
    log_format = "[codechecker] %(levelname)5s: %(message)s"

    if log_file_name():
        logging.basicConfig(filename=log_file_name(), level=log_level, format=log_format)
    else:
        logging.basicConfig(level=log_level, format=log_format)


def input_data():
    """ Print out input (external) parameters """
    stage("CodeChecker input data:", "debug")
    logging.debug("       VERBOSITY     : %s", str(VERBOSITY))
    logging.debug("CODECHECKER_PATH     : %s", str(CODECHECKER_PATH))
    logging.debug("CODECHECKER_SKIPFILE : %s", str(CODECHECKER_SKIPFILE))
    logging.debug("CODECHECKER_FILES    : %s", str(CODECHECKER_FILES))
    logging.debug("CODECHECKER_LOG      : %s", str(CODECHECKER_LOG))
    logging.debug("COMPILE_COMMANDS     : %s", str(COMPILE_COMMANDS))
    logging.debug("")


def execute(cmd, env=None):
    """ Execute CodeChecker commands """
    process = subprocess.Popen(
        cmd,
        env=env,
        shell=True,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    stdout, stderr = process.communicate()
    if process.returncode != 0:
        fail("\ncommand: %s\nstdout: %s\nstderr: %s\n" % (cmd, stdout, stderr))
    logging.debug("Executing: %s", cmd)
    # logging.debug("Output:\n\n%s\n", stdout)
    return stdout


def create_folder(path):
    """ Create folder structure for CodeChecker data files and reports """
    if not os.path.exists(path):
        os.makedirs(path)


def prepare():
    """ Prepare CodeChecker execution environment """
    stage("CodeChecker files:")
    logging.info("Creating folder: %s", CODECHECKER_FILES)
    create_folder(CODECHECKER_FILES)


def analyze():
    """ Run CodeChecker analyze command """
    stage("CodeChecker analyze:")
    env = {
        "CC_ANALYZERS_FROM_PATH": "1",
    }
    logging.debug("env: %s", str(env))
    # FIXME: add analyze_extra_args?
    command = "%s analyze --jobs=%d --skip=%s %s --output=%s/data" % (
        CODECHECKER_PATH,
        multiprocessing.cpu_count(),
        CODECHECKER_SKIPFILE,
        COMPILE_COMMANDS,
        CODECHECKER_FILES,
    )
    logging.info("Running CodeChecker analyze...")
    # output = execute("pwd")  #, env=env)
    # logging.info("pwd:\n\n%s\n", output)
    # output = execute("ls -la")  #, env=env)
    # logging.info("ls -la:\n\n%s\n", output)
    output = execute(command)  #, env=env)
    logging.info("Output:\n\n%s\n", output)
    if output.find("- Failed to analyze") != -1:
        logging.error("CodeChecker failed to analyze some files")
        fail("Make sure that the target can be built first")


def run():
    """ Perform all steps for "bazel build" phase """
    prepare()
    analyze()


def main():
    """ Main function """
    setup()
    input_data()
    try:
        run()
    except Exception as error:
        logging.exception(error)
        fail("Caught Exception. Terminated")


if __name__ == "__main__":
    main()
