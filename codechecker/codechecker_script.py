#!/usr/bin/env python
"""
CodeChecker Bazel build & test wrapper script
"""

from __future__ import print_function
import getpass
import json
import logging
import multiprocessing
import os
import re
import shlex
import subprocess


VERBOSITY = "{Verbosity}"
COMPILE_COMMANDS = "{compile_commands}"
CODECHECKER_PATH = "{codecheckerPATH}"
CODECHECKER_SKIPFILE = "{codechecker_skipfile}"
CODECHECKER_FILES = "{codechecker_files}"
CODECHECKER_LOG = "{codechecker_log}"
CODECHECKER_COMMANDS = os.path.join(CODECHECKER_FILES, "codechecker-commands.json")
CODECHECKER_SEVERITIES = "{codechecker_severities}"


def fail(message, exit_code=1):
    """ Print error message and return exit code """
    logging.error(message)
    print()
    print("*" * 50)
    print("codechecker script execution FAILED!")
    # if log_file_name():
    #     print("See: %s" % log_file_name())
    #     print("*" * 50)
    #     try:
    #         with open(log_file_name()) as log_file:
    #             print(log_file.read())
    #     except IOError:
    #         print("File not accessible")
    # else:
    #     print(message)
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
    logging.debug("VERBOSITY              : %s", str(VERBOSITY))
    logging.debug("COMPILE_COMMANDS       : %s", str(COMPILE_COMMANDS))
    logging.debug("CODECHECKER_PATH       : %s", str(CODECHECKER_PATH))
    logging.debug("CODECHECKER_SKIPFILE   : %s", str(CODECHECKER_SKIPFILE))
    logging.debug("CODECHECKER_FILES      : %s", str(CODECHECKER_FILES))
    logging.debug("CODECHECKER_LOG        : %s", str(CODECHECKER_LOG))
    logging.debug("CODECHECKER_COMMANDS   : %s", str(CODECHECKER_COMMANDS))
    logging.debug("CODECHECKER_SEVERITIES : %s", str(CODECHECKER_SEVERITIES))
    logging.debug("")
    # output = execute("pwd")
    # logging.debug("PWD: %s", output)
    # output = execute("ls -la")
    # logging.debug("DIR:\n%s", output)


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


def fix_paths():
    """ Parse compile_commands.json and fix source file paths """
    if not os.path.exists(CODECHECKER_FILES):
        fail("Folder for CodeChecker files '%s' does not exist" % CODECHECKER_FILES)

    cwd = os.getcwd()
    logging.debug("Original CWD: %s", cwd)

    output = execute("ls -la test")
    logging.debug("DIR:\n%s", output)


    path = re.sub(r"sandbox\/processwrapper-sandbox\/\S*\/execroot", "execroot", cwd)
    logging.debug("    Real CWD: %s", path)
    if not os.path.exists(path):
        fail("Path %s does not exist" % path)
    logging.debug("Input file: %s", COMPILE_COMMANDS)
    with open(COMPILE_COMMANDS, "r") as input_file:
        compile_commands = json.load(input_file)
        logging.info("Compile commands size: %d", len(compile_commands))
        # logging.debug("Read compile commands:\n\n%s\n", compile_commands)
    for item in compile_commands:
        directory = item["directory"]
        filename = item["file"]
        item["directory"] = path
        item["file"] = filename
    # logging.debug("Converted compile commands:\n\n%s\n", compile_commands)
    logging.debug("Saving to: %s", CODECHECKER_COMMANDS)
    with open(CODECHECKER_COMMANDS, "w") as output_file:
        json.dump(compile_commands, output_file, indent=4)


def prepare():
    """ Prepare CodeChecker execution environment """
    stage("CodeChecker files:")
    logging.info("Creating folder: %s", CODECHECKER_FILES)
    create_folder(CODECHECKER_FILES)
    fix_paths()


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
        CODECHECKER_COMMANDS,
        CODECHECKER_FILES,
    )
    logging.info("Running CodeChecker analyze...")
    output = execute(command)  #, env=env)
    logging.info("Output:\n\n%s\n", output)
    if output.find("- Failed to analyze") != -1:
        logging.error("CodeChecker failed to analyze some files")
        fail("Make sure that the target can be built first")


def fix_output():
    """ Change "/sandbox/.../execroot/" paths to "/execroot/" in all files """
    stage("Fix CodeChecker output:")
    folder = CODECHECKER_FILES
    pattern = r"\/sandbox\/processwrapper-sandbox\/\S*\/execroot\/"
    replace = "/execroot/"
    logging.info("Fixing sandbox paths in %s", folder)
    logging.info("   /sandbox/processwrapper-sandbox/.../execroot/ -> /execroot/")
    counter = 0
    for root, _, files in os.walk(folder):
        for filename in files:
            fullpath = os.path.join(root, filename)
            with open(fullpath, "rt") as data_file:
                data = data_file.read()
                data = re.sub(pattern, replace, data)
            with open(fullpath, "w") as data_file:
                data_file.write(data)
            counter += 1
    logging.info("Fixed sandbox paths in %d files", counter)


def parse():
    """ Run CodeChecker parse commands """
    stage("CodeChecker parse:")
    logging.info("CodeChecker parse -e json")
    codechecker_parse = CODECHECKER_PATH + " parse " + CODECHECKER_FILES + "/data "
    # Save results to JSON file
    command = codechecker_parse + "--export=json > " + CODECHECKER_FILES + "/result.json"
    execute(command)
    # logging.debug("JSON:\n\n%s\n", read_file(CODECHECKER_FILES + "/result.json"))
    # Save results as HTML report
    logging.info("CodeChecker parse -e html")
    command = codechecker_parse + "--export=html --output=" + CODECHECKER_FILES + "/report"
    execute(command)
    # Save results to text file
    logging.info("CodeChecker parse to text result")
    command = codechecker_parse + "> " + CODECHECKER_FILES + "/result.txt"
    execute(command)
    logging.info("Result:\n\n%s\n", read_file(CODECHECKER_FILES + "/result.txt"))


def check_results():
    """ Check/verify CodeChecker results """
    stage("Checking result:")
    # Get results file and read it
    result_file = CODECHECKER_FILES + "/result.txt"
    logging.info("Find CodeChecker results in bazel-out")
    logging.info("      all artifacts: %s/", CODECHECKER_FILES)
    logging.info("      HTML report:   %s/report/index.html", CODECHECKER_FILES)
    logging.info("      result file:   %s", result_file)
    results = read_file(result_file)
    logging.info("Results: \n\n%s\n", results)
    # Collect defect severities to detect
    if not valid_parameter(CODECHECKER_SEVERITIES):
        fail("CodeChecker defect severities are invalid: %s" % str(CODECHECKER_SEVERITIES))
    severities = shlex.split(CODECHECKER_SEVERITIES)
    # Add HIGH severity by default
    if not severities:
        severities.append("HIGH")
    # We should always detect CRITICAL defects
    if "CRITICAL" not in severities:
        severities.append("CRITICAL")
    logging.debug("Severities: %s", str(severities))
    issues = dict.fromkeys(severities, 0)
    logging.debug("Issues: %s", str(issues))
    # Grep results for defects according to severities
    for issue in issues:
        found = re.findall(r"^%s .* (\d+)" % issue, results, re.M)
        defects = sum([int(number) for number in found])
        logging.debug("   %s : %s = %d", issue, str(found), defects)
        issues[issue] = defects
    logging.info("Defects: %s", str(issues))
    # Check collected defects
    passed = True
    conclusion = ""
    for issue in issues:
        if issues[issue] > 0:
            passed = False
            conclusion += "%15s : %d\n" % (issue, issues[issue])
    if passed:
        logging.info("No defects found by CodeChecker")
    else:
        fail("CodeChecker found defects:\n%s" % conclusion)


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
