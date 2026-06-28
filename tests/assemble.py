# Assemble risc-v assembly programs into little-endian hex files read by sv.
#
# Two flavours, auto-detected:
#   - plain programs (e.g. smoke.S)         -> tests/link.ld
#   - riscv-tests (include "riscv_test.h")  -> tests/riscv_test.ld + macro -I's

import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")
TESTS = os.path.join(ROOT, "tests")
RISCV_TESTS = os.path.join(ROOT, "third_party", "riscv-tests")
MACROS = os.path.join(RISCV_TESTS, "isa", "macros", "scalar")

LDSCRIPT = os.path.join(TESTS, "link.ld")
RVTEST_LD = os.path.join(TESTS, "riscv_test.ld")

RVCC = os.environ.get("RVCC", "riscv64-unknown-elf-gcc")
RVCOPY = os.environ.get("RVCOPY", "riscv64-unknown-elf-objcopy")
RVFLAGS = ["-march=rv32i", "-mabi=ilp32", "-nostdlib", "-nostartfiles"]


def is_riscv_test(src):
    with open(src) as f:
        return "riscv_test.h" in f.read()


def bin_to_hex(bin_path, hex_path):
    data = open(bin_path, "rb").read()
    if len(data) % 4: data += b"\x00" * (4 - len(data) % 4)
    with open(hex_path, "w") as f:
        for i in range(0, len(data), 4):
            f.write("%08x\n" % struct.unpack("<I", data[i:i + 4])[0])


def build(src):
    name = os.path.splitext(os.path.basename(src))[0]
    elf = os.path.join(BUILD, name + ".elf")
    binf = os.path.join(BUILD, name + ".bin")
    hexf = os.path.join(BUILD, name + ".hex")

    if is_riscv_test(src):
        flags = RVFLAGS + ["-I", TESTS, "-I", MACROS, "-T", RVTEST_LD]
    else:
        flags = RVFLAGS + ["-T", LDSCRIPT]

    os.makedirs(BUILD, exist_ok=True)
    subprocess.run([RVCC, *flags, "-o", elf, src], check=True)
    subprocess.run([RVCOPY, "-O", "binary", elf, binf], check=True)
    bin_to_hex(binf, hexf)
    return hexf


def main(argv):
    os.makedirs(BUILD, exist_ok=True)
    srcs = argv[1:]
    if not srcs:
        srcs = sorted(
            os.path.join(TESTS, f) for f in os.listdir(TESTS) if f.endswith(".S")
        )
    for src in srcs:
        print("built", build(src))


if __name__ == "__main__":
    main(sys.argv)
