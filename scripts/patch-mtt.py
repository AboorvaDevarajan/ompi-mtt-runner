#!/usr/bin/env python3
"""Idempotent patches to the local open-mpi/mtt clone.

MPIVersion.py uses bare `mpiexec`, which refuses to run as root.
Autotools also calls MPIVersion before mpicc exists. After a successful
install (or ASIS reuse), probe again with prefix/bin on PATH.
"""
import sys
from pathlib import Path

MPIVERSION_OLD = (
    "sh -c \"mpiexec ./mpi_get_version |sort |uniq -c\""
)
MPIVERSION_NEW = (
    "sh -c \"mpiexec --allow-run-as-root --oversubscribe "
    "./mpi_get_version |sort |uniq -c\""
)

HELPER = '''
def _mtt_runner_probe_mpi(log, testDef, pfx):
    """Re-run MPIVersion after mpicc is on PATH (ompi-mtt-runner)."""
    bindir = os.path.join(pfx, "bin")
    oldpath = os.environ.get("PATH", "")
    if os.path.isdir(bindir):
        os.environ["PATH"] = bindir + os.pathsep + oldpath
    plugin = None
    try:
        for util in list(testDef.loader.utilities.keys()):
            for pluginInfo in testDef.utilities.getPluginsOfCategory(util):
                if "MPIVersion" == pluginInfo.plugin_object.print_name():
                    plugin = pluginInfo.plugin_object
                    break
            if plugin is not None:
                break
        if plugin is not None:
            mpi_info = {}
            plugin.execute(mpi_info, testDef)
            log["mpi_info"] = mpi_info
            testDef.logger.verbose_print("MPIVersion after install: " + str(mpi_info))
    finally:
        os.environ["PATH"] = oldpath

'''

ASIS_OLD = """                    testDef.logger.verbose_print("As-Is location " + pfx + " exists and has 'build_complete file")
                    # nothing further to do
                    log['status'] = 0
                    return
"""

ASIS_NEW = """                    testDef.logger.verbose_print("As-Is location " + pfx + " exists and has 'build_complete file")
                    log['status'] = 0
                    _mtt_runner_probe_mpi(log, testDef, pfx)
                    return
"""

INSTALL_OLD = """        # Add confirmation that build is complete
        try:
            confirmation = os.path.join(pfx, 'build_complete')
"""

INSTALL_NEW = """        if 0 == results['status']:
            _mtt_runner_probe_mpi(log, testDef, pfx)

        # Add confirmation that build is complete
        try:
            confirmation = os.path.join(pfx, 'build_complete')
"""


def patch_mpiversion(mtt_home: Path) -> bool:
    path = mtt_home / "pylib" / "Utilities" / "MPIVersion.py"
    text = path.read_text()
    if "--allow-run-as-root" in text:
        return False
    if MPIVERSION_OLD not in text:
        raise SystemExit(f"MPIVersion.py: expected mpiexec line not found in {path}")
    path.write_text(text.replace(MPIVERSION_OLD, MPIVERSION_NEW, 1))
    return True


def patch_autotools(mtt_home: Path) -> bool:
    path = mtt_home / "pylib" / "Tools" / "Build" / "Autotools.py"
    text = path.read_text()
    changed = False
    if "_mtt_runner_probe_mpi" not in text:
        needle = "class Autotools(BuildMTTTool):"
        if needle not in text:
            raise SystemExit(f"Autotools.py: class line not found in {path}")
        text = text.replace(needle, HELPER + needle, 1)
        changed = True
    if ASIS_OLD in text:
        text = text.replace(ASIS_OLD, ASIS_NEW, 1)
        changed = True
    if INSTALL_OLD in text and "if 0 == results['status']:\n            _mtt_runner_probe_mpi" not in text:
        text = text.replace(INSTALL_OLD, INSTALL_NEW, 1)
        changed = True
    if changed:
        path.write_text(text)
    return changed


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} MTT_HOME")
    mtt_home = Path(sys.argv[1])
    if not (mtt_home / "pyclient" / "pymtt.py").is_file():
        raise SystemExit(f"not an MTT tree: {mtt_home}")
    a = patch_mpiversion(mtt_home)
    b = patch_autotools(mtt_home)
    print("patched MPIVersion.py" if a else "MPIVersion.py already patched")
    print("patched Autotools.py" if b else "Autotools.py already patched")


if __name__ == "__main__":
    main()
