"""
Filter compile_commands.json file
- to convert "flacc" calls to "clang"
- to remove unsupported clang and gcc flags
- to fix "virtual includes" paths
"""

from __future__ import print_function
import argparse
import json
import logging
import os
import re
import shlex
import subprocess


COMPILE_COMMANDS_FILTER = {
    # GCC: filter out unsupported options
    r".*\/bin\/gcc ": {
        r" -fno-canonical-system-headers ": " ",
    },
    # clang: filter out unsupported options
    r".*\/bin\/clang ": {
        r" -MD ": " ",
        r" -MF \S* ": " ",
        r" -MT \S* ": " ",
    },
}


def parse_args():
    """
    Parse command line arguments or show help.
    """
    parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter,
                                     description=__doc__)
    parser.add_argument("-i", "--input",
                        default="compile_commands.json",
                        help="input compile_commands.json file")
    parser.add_argument("-o", "--output",
                        default="compile_commands.json",
                        help="output compile_commands.json file")
    parser.add_argument("-v", "--verbosity",
                        default=0,
                        action="count",
                        help="increase output verbosity (e.g., -v or -vv)")
    parser.add_argument("--log-format",
                        default="[FILTER] %(levelname)5s: %(message)s",
                        help=argparse.SUPPRESS)

    options = parser.parse_args()

    if options.verbosity >= 2:
        log_level = logging.DEBUG
    elif options.verbosity >= 1:
        log_level = logging.INFO
    else:
        log_level = logging.WARN
    logging.basicConfig(level=log_level, format=options.log_format)

    return options


def split_to_list(arguments):
    """
    Split argument string to list
    """
    if isinstance(arguments, list):
        return arguments
    return shlex.split(arguments)


def run_command(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE):
    """
    Run shell command
    """
    cmd = split_to_list(command)
    process = subprocess.Popen(cmd, stdout=stdout, stderr=stderr)
    out, err = process.communicate()
    if err:
        logging.error("Command: %s...\nError: %s", command, err)
    return out


def convert_flacc_to_clang(compile_commands):
    """
    Convert flacc call to clang in compile_commands
    """
    for item in compile_commands:
        command = item["command"]
        if command.find("/flacc ") == -1:
            continue
        source_file = item["file"]
        logging.info("Converting from flacc to clang for: %s", source_file)
        logging.debug("from flacc: %s...", command[0:80])
        out = run_command(command + " " + source_file + " -dry-run")
        logging.debug("result:\n\n%s\n", out)
        for line in out.splitlines():
            line = line.decode("utf8")
            if line.find("/clang ") != -1:
                logging.debug("  to clang: %s...", line[0:80])
                item["command"] = line
                break
    return compile_commands


def filter_compile_flags(compile_commands):
    """
    Remove unrecognized flags from compile commands
    """
    logging.info("Filtering compile flags")
    for item in compile_commands:
        command = item["command"]
        for rule in COMPILE_COMMANDS_FILTER:
            if re.search(rule, command):
                rules = COMPILE_COMMANDS_FILTER[rule]
                for pattern in rules:
                    logging.debug("applying: '%s' -> '%s'", pattern, rules[pattern])
                    logging.debug("    from: %s...", command)
                    command = re.sub(pattern, rules[pattern], command)
                    logging.debug("      to: %s...", command)
        item["command"] = command

    return compile_commands


def main():
    """
    Main function
    """
    options = parse_args()
    logging.debug("Options: %s", options)

    logging.info("Input file: %s", options.input)
    with open(options.input, "r") as input_file:
        compile_commands = json.load(input_file)
        logging.info("Compile commands size: %d", len(compile_commands))
        logging.debug("Read compile commands:\n\n%s\n", compile_commands)

    # compile_commands = convert_flacc_to_clang(compile_commands)
    # compile_commands = filter_compile_flags(compile_commands)

    # print(">>>>>>>> os.getcwd()=%s" % os.getcwd())
    # out = run_command("bazel info execution_root")
    # print(">>>>>>>> execution_root=%s" % out)

    logging.debug("Converted compile commands:\n\n%s\n", compile_commands)
    logging.info("Saving to: %s", options.output)
    with open(options.output, "w") as output_file:
        json.dump(compile_commands, output_file, indent=4)


if __name__ == "__main__":
    main()
