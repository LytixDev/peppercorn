#Build and run:
# ./sim.py
# ./sim.py run_tb +HEX=build/add.hex
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(ROOT, "build")
RTL = os.path.join(ROOT, "rtl")
TB = os.path.join(ROOT, "tb")


def main(argv):
    top = argv[1] if len(argv) > 1 else "core_tb"
    plusargs = argv[2:]

    os.makedirs(BUILD, exist_ok=True)

    # Packages must come first as Icarus reads in order and does not resolve dependencies itself
    pkgs = sorted(glob.glob(os.path.join(RTL, "*_pkg.sv")))
    rtl_rest = [f for f in sorted(glob.glob(os.path.join(RTL, "*.sv"))) if f not in pkgs]
    tb = sorted(glob.glob(os.path.join(TB, "*.sv")))
    sources = pkgs + rtl_rest + tb

    vvp_file = os.path.join(BUILD, top + ".vvp")

    subprocess.run(
        ["iverilog", "-g2012", "-Wall", "-s", top, "-o", vvp_file, *sources],
        check=True,
    )
    sys.exit(subprocess.run(["vvp", vvp_file, *plusargs]).returncode)


if __name__ == "__main__":
    main(sys.argv)
