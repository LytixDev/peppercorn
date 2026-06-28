# Run the supported rv32ui riscv-tests.
# ./run_tests.py          # run the supported subset
# ./run_tests.py add sub  # run just these

import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "tests"))
import assemble  # noqa: E402

BUILD = os.path.join(ROOT, "build")
RTL = os.path.join(ROOT, "rtl")
TB = os.path.join(ROOT, "tb")
RV32UI = os.path.join(ROOT, "third_party", "riscv-tests", "isa", "rv32ui")

SUPPORTED = [
    "simple", "add", "addi", "sub", "and", "andi", "or", "ori", "xor", "xori",
    "sll", "slli", "srl", "srli", "sra", "srai",
    "slt", "slti", "sltu", "sltiu",
    "lui", "auipc",
    "beq", "bne", "blt", "bge", "bltu", "bgeu",
    "jal", "jalr",
    "lw", "sw",
]

SKIP = {
    "lb", "lbu", "lh", "lhu", "sb", "sh", "fence_i", "ma_data"
}


def compile_runner():
    pkgs = sorted(glob.glob(os.path.join(RTL, "*_pkg.sv")))
    rtl_rest = [f for f in sorted(glob.glob(os.path.join(RTL, "*.sv"))) if f not in pkgs]
    tb = sorted(glob.glob(os.path.join(TB, "*.sv")))
    vvp = os.path.join(BUILD, "run_tb.vvp")
    os.makedirs(BUILD, exist_ok=True)
    r = subprocess.run(
        ["iverilog", "-g2012", "-s", "run_tb", "-o", vvp, *pkgs, *rtl_rest, *tb],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit("compile failed:\n" + r.stderr)
    return vvp


def run_one(vvp, name):
    hexf = assemble.build(os.path.join(RV32UI, name + ".S"))
    out = subprocess.run([vvp, "+HEX=" + hexf], capture_output=True, text=True).stdout
    for line in out.splitlines():
        word = line.split()
        if word and word[0] in ("PASS", "FAIL", "TIMEOUT"):
            return word[0], line.strip()
    return "ERROR", out.strip()


def main(argv):
    names = argv[1:] or SUPPORTED
    vvp = compile_runner()

    npass = 0
    failures = []
    for name in names:
        status, detail = run_one(vvp, name)
        mark = "ok " if status == "PASS" else "XXX"
        print(f"  [{mark}] {name:8} {detail if status != 'PASS' else ''}".rstrip())
        if status == "PASS":
            npass += 1
        else:
            failures.append(name)

    print(f"\n{npass}/{len(names)} passed")
    if not argv[1:]:
        print("skipped: " + ", ".join(i for i in SKIP))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main(sys.argv)
