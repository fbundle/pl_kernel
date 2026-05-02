from __future__ import annotations

import os
import selectors
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, Sequence


class ReplError(RuntimeError):
    pass


@dataclass(frozen=True)
class ReplStep:
    out: str
    err: str
    prompt: str


class Repl:
    """
    Generic Python client for the `REPL.run` protocol used by this repo.
    """

    def __init__(
        self,
        argv: Sequence[str | os.PathLike[str]],
        *,
        cwd: str | os.PathLike[str] | None = None,
        prompt: str = "> ",
        encoding: str = "utf-8",
        read_timeout_s: float = 5.0,
        env: Optional[dict[str, str]] = None,
    ) -> None:
        self._argv = [str(a) for a in argv]
        self._cwd = str(Path(cwd)) if cwd is not None else None
        self._prompt_str = prompt
        self._prompt_bytes = prompt.encode(encoding)
        self._encoding = encoding
        self._read_timeout_s = float(read_timeout_s)
        self._env = env

        self._p: Optional[subprocess.Popen[bytes]] = None
        self._last: Optional[ReplStep] = None

    def start(self) -> "Repl":
        if self._p is not None:
            return self

        self._p = subprocess.Popen(
            self._argv,
            cwd=self._cwd,
            env=self._env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
            bufsize=0,
        )

        out, err = self._read_until_prompt()
        self._last = ReplStep(out=out, err=err, prompt=self._prompt_str)
        return self

    def close(self) -> None:
        if self._p is None:
            return
        try:
            if self._p.stdin:
                self._p.stdin.close()
        finally:
            self._p.terminate()
            try:
                self._p.wait(timeout=1.0)
            except Exception:
                self._p.kill()
                self._p.wait(timeout=1.0)
        self._p = None

    def __enter__(self) -> "Repl":
        return self.start()

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def last(self) -> ReplStep:
        if self._last is None:
            self.start()
        assert self._last is not None
        return self._last

    def send(self, line: str) -> ReplStep:
        self.start()
        assert self._p is not None and self._p.stdin is not None

        self._p.stdin.write((line.rstrip("\n") + "\n").encode(self._encoding))
        self._p.stdin.flush()

        out, err = self._read_until_prompt()
        self._last = ReplStep(out=out, err=err, prompt=self._prompt_str)
        return self._last

    def _read_until_prompt(self) -> tuple[str, str]:
        assert self._p is not None and self._p.stdout is not None and self._p.stderr is not None

        out_buf = bytearray()
        err_buf = bytearray()

        sel = selectors.DefaultSelector()
        sel.register(self._p.stdout, selectors.EVENT_READ)
        sel.register(self._p.stderr, selectors.EVENT_READ)

        try:
            while True:
                events = sel.select(timeout=self._read_timeout_s)
                if not events:
                    code = self._p.poll()
                    if code is not None:
                        raise ReplError(f"process terminated (exit_code={code})")
                    continue

                for key, _mask in events:
                    chunk = os.read(key.fileobj.fileno(), 4096)
                    if chunk == b"":
                        code = self._p.poll()
                        raise ReplError(f"process terminated (exit_code={code})")

                    if key.fileobj is self._p.stdout:
                        out_buf.extend(chunk)
                    else:
                        err_buf.extend(chunk)

                    if self._prompt_bytes in err_buf:
                        idx = err_buf.index(self._prompt_bytes)
                        prompt_end = idx + len(self._prompt_bytes)
                        captured_err = bytes(err_buf[:idx])
                        del err_buf[:prompt_end]

                        while True:
                            extra = sel.select(timeout=0)
                            if not extra:
                                break
                            for k2, _m2 in extra:
                                if k2.fileobj is not self._p.stdout:
                                    continue
                                more = os.read(k2.fileobj.fileno(), 4096)
                                if more:
                                    out_buf.extend(more)

                        return (
                            out_buf.decode(self._encoding, errors="replace").rstrip("\n"),
                            captured_err.decode(self._encoding, errors="replace").rstrip("\n"),
                        )
        finally:
            for stream in (self._p.stdout, self._p.stderr):
                try:
                    sel.unregister(stream)
                except Exception:
                    pass
            sel.close()

