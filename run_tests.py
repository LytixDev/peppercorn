# ./run_tests.py                    # run riscv-tests 
# ./run_tests.py add sub            # run just these
# ./run_tests.py --benchmark        # run coremark benchmark

import datetime
import glob
import json
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
    "lw", "lb", "lh", "sw", "sb", "sh", "lbu", "lhu",
]

SKIP = {
    "fence_i", "ma_data"
}

RUNS = os.path.join(ROOT, "runs")
SYSTEM_META = os.path.join(ROOT, "system_meta.json")
COREMARK_DIR = os.path.join(ROOT, "coremark")


def load_system_meta():
    try:
        with open(SYSTEM_META) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def compile_runner(benchmark=False):
    pkgs = sorted(glob.glob(os.path.join(RTL, "*_pkg.sv")))
    rtl_rest = [f for f in sorted(glob.glob(os.path.join(RTL, "*.sv"))) if f not in pkgs]
    tb = sorted(glob.glob(os.path.join(TB, "*.sv")))
    vvp = os.path.join(BUILD, "run_tb.vvp")
    os.makedirs(BUILD, exist_ok=True)
    flags = ["-DBENCHMARK"] if benchmark else []
    r = subprocess.run(
        ["iverilog", "-g2012", "-s", "run_tb", "-o", vvp, *flags, *pkgs, *rtl_rest, *tb],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit("compile failed:\n" + r.stderr)
    return vvp


def build_coremark():
    r = subprocess.run(["make", "-C", COREMARK_DIR], capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit("coremark build failed:\n" + r.stderr)
    return os.path.join(BUILD, "coremark.hex")


def run_one(vvp, name):
    if name == "coremark":
        hexf = build_coremark()
        args = [vvp, "+HEX=" + hexf, "+TIMEOUT=5000000", "+TOHOST=32768"]
    else:
        hexf = assemble.build(os.path.join(RV32UI, name + ".S"))
        args = [vvp, "+HEX=" + hexf]
    out = subprocess.run(args, capture_output=True, text=True).stdout
    for line in out.splitlines():
        word = line.split()
        if word and word[0] in ("PASS", "FAIL", "TIMEOUT"):
            kv = {}
            for token in word[1:]:
                if "=" in token:
                    k, _, v = token.partition("=")
                    try: kv[k] = int(v)
                    except ValueError: pass
            return word[0], line.strip(), kv
    return "ERROR", out.strip(), {}


def save_run(results, total_cycles, total_instrs, npass, names,
             total_bp_resolved=0, total_bp_mispredicts=0):
    os.makedirs(RUNS, exist_ok=True)
    ts = datetime.datetime.now()
    entry = {
        "timestamp": ts.isoformat(timespec="seconds"),
        "system": load_system_meta(),
        "tests": results,
        "summary": {
            "passed": npass,
            "total": len(names),
            "total_cycles": total_cycles,
            "total_instrs": total_instrs,
            "weighted_ipc": round(total_instrs / total_cycles, 4) if total_cycles else 0,
            "bp_resolved": total_bp_resolved,
            "bp_mispredicts": total_bp_mispredicts,
            "bp_accuracy": round((total_bp_resolved - total_bp_mispredicts) / total_bp_resolved, 4)
                           if total_bp_resolved else 0,
            "bp_mpki": round(total_bp_mispredicts / total_instrs * 1000, 2) if total_instrs else 0,
        },
    }
    fname = ts.strftime("%Y-%m-%dT%H-%M-%S") + ".json"
    with open(os.path.join(RUNS, fname), "w") as f:
        json.dump(entry, f, indent=4)
    print(f"run saved to runs/{fname}")


def main(argv):
    benchmark = "--benchmark" in argv
    args = [a for a in argv[1:] if not a.startswith("--")]
    names = args or (["coremark"] if benchmark else SUPPORTED)
    vvp = compile_runner(benchmark)

    npass = 0
    failures = []
    total_cycles = 0
    total_instrs = 0
    total_bp_resolved = 0
    total_bp_mispredicts = 0
    results = []
    for name in names:
        status, detail, kv = run_one(vvp, name)
        mark = "ok " if status == "PASS" else "XXX"
        suffix = ""
        if benchmark and kv:
            cycles, instrs = kv.get("cycles", 0), kv.get("instrs", 0)
            ipc = instrs / cycles if cycles else 0
            bp_resolved, bp_mispredicts = kv.get("bp_resolved", 0), kv.get("bp_mispredicts", 0)
            bp_accuracy = (bp_resolved - bp_mispredicts) / bp_resolved if bp_resolved else 0
            bp_mpki = bp_mispredicts / instrs * 1000 if instrs else 0
            suffix = f"  {cycles} cycles  {instrs} instrs  IPC={ipc:.3f}  BP={bp_accuracy:.1%}  MPKI={bp_mpki:.2f}"
            results.append({"name": name, "status": status, "cycles": cycles, "instrs": instrs, "ipc": round(ipc, 4),
                            "bp_resolved": bp_resolved, "bp_mispredicts": bp_mispredicts,
                            "bp_accuracy": round(bp_accuracy, 4), "bp_mpki": round(bp_mpki, 2)})
            if status == "PASS":
                total_cycles += cycles
                total_instrs += instrs
                total_bp_resolved += bp_resolved
                total_bp_mispredicts += bp_mispredicts
        print(f"  [{mark}] {name:8} {detail if status != 'PASS' else ''}{suffix}".rstrip())
        if status == "PASS":
            npass += 1
        else:
            failures.append(name)

    print(f"\n{npass}/{len(names)} passed")
    if benchmark and total_cycles:
        print(f"weighted avg IPC: {total_instrs / total_cycles:.3f}  ({total_instrs} instrs / {total_cycles} cycles)")
        if total_bp_resolved:
            acc = (total_bp_resolved - total_bp_mispredicts) / total_bp_resolved
            mpki = total_bp_mispredicts / total_instrs * 1000 if total_instrs else 0
            print(f"BP accuracy: {acc:.1%}  ({total_bp_mispredicts} mispredicts / {total_bp_resolved} resolved)  MPKI: {mpki:.2f}")
        save_run(results, total_cycles, total_instrs, npass, names,
                 total_bp_resolved, total_bp_mispredicts)
    if not args and not benchmark:
        print("skipped: " + ", ".join(i for i in SKIP))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    main(sys.argv)
