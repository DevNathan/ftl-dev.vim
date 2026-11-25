"""Exercise editor input and the development profiles in their real event loops."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

here = Path(__file__).resolve().parent


def run_session(editor, script, fixture, dev):
    if dev:
        command = ["bash", str(here / "dev.sh"), editor]
    else:
        command = [editor, "-Nu", str(here / "vimrc"), "-i", "NONE", "-n"]
    command += ["--not-a-term" if editor == "vim" else "--headless",
                str(here / "fixtures" / fixture), "-S", str(here / script)]
    with tempfile.TemporaryDirectory() as tmp:
        result = Path(tmp, "result")
        env = {**os.environ, "FTL_TEST_RESULT": str(result), "FTL_TEST_LSP": str(int(dev))}
        env.setdefault("XDG_STATE_HOME", tmp)
        # Keep stdin open while timer callbacks return control to the input loop.
        with subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                              stderr=subprocess.PIPE, env=env) as proc:
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                proc.kill()
                raise SystemExit(f"{editor} timed out during {script}")
            report = result.read_text(encoding="utf-8").strip() if result.exists() else ""
            if proc.returncode or report != "passed":
                raise SystemExit(f"{editor} {script} failed. {report}\n{proc.stderr.read().decode(errors='replace')}")
    print(f"{editor} {script} passed.")


dev = sys.argv[1:] == ["--dev"]
for editor in ("vim", "nvim"):
    run_session(editor, "linked-editing.vim", "linked-tags.ftl", dev)
    run_session(editor, "completion-menu.vim", "main.ftl", dev)
