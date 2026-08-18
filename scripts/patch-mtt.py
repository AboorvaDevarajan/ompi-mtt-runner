#!/usr/bin/env python3
"""Idempotent patches to the local open-mpi/mtt clone.

MPIVersion.py uses bare `mpiexec`, which refuses to run as root.
Autotools also calls MPIVersion before mpicc exists. After a successful
install (or ASIS reuse), probe again with prefix/bin on PATH.

LauncherMTTTool walks into libtool .libs/ and then skip_tests only
matches the last basename, so wrappers still run.
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


WALK_OLD = "for dirName, subdirList, fileList in os.walk(dr):"
WALK_NEW = "for dirName, subdirList, fileList in self._walk_tests(dr):"
WALK_DOT_OLD = 'for dirName, subdirList, fileList in os.walk("."):'
WALK_DOT_NEW = 'for dirName, subdirList, fileList in self._walk_tests("."):'

WALK_HELPER = '''
    def _walk_tests(self, root):
        """Skip libtool .libs copies so each test is collected once."""
        skip_dirs = {".libs", ".deps", "autom4te.cache"}
        for dirName, subdirList, fileList in os.walk(root):
            subdirList[:] = [s for s in subdirList if s not in skip_dirs]
            yield dirName, subdirList, fileList

'''

SKIP_OLD = """        for i,t in enumerate(self.skip_tests):
            for t2 in self.tests:
                if t2.split("/")[-1] == t:
                    self.skip_tests[i] = t2
        # all done
        return 0
"""

SKIP_NEW = """        resolved = []
        for t in self.skip_tests:
            if not t:
                continue
            matched = False
            for t2 in self.tests:
                if t2.split("/")[-1] == t:
                    resolved.append(t2)
                    matched = True
            if not matched:
                resolved.append(t)
        self.skip_tests = resolved
        # all done
        return 0
"""


def patch_launcher(mtt_home: Path) -> bool:
    path = mtt_home / "pylib" / "Tools" / "Launcher" / "LauncherMTTTool.py"
    text = path.read_text()
    changed = False
    if "def _walk_tests(self, root):" not in text:
        needle = "    def collectTests(self, log, cmds):"
        if needle not in text:
            raise SystemExit(f"LauncherMTTTool.py: collectTests not found in {path}")
        text = text.replace(needle, WALK_HELPER + needle, 1)
        changed = True
    if WALK_OLD in text:
        text = text.replace(WALK_OLD, WALK_NEW)
        changed = True
    if WALK_DOT_OLD in text:
        text = text.replace(WALK_DOT_OLD, WALK_DOT_NEW)
        changed = True
    if SKIP_OLD in text:
        text = text.replace(SKIP_OLD, SKIP_NEW, 1)
        changed = True
    if changed:
        path.write_text(text)
    return changed


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
    c = patch_launcher(mtt_home)
    print("patched MPIVersion.py" if a else "MPIVersion.py already patched")
    print("patched Autotools.py" if b else "Autotools.py already patched")
    print("patched LauncherMTTTool.py" if c else "LauncherMTTTool.py already patched")


if __name__ == "__main__":
    main()
