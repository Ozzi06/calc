import os
import sys
import atexit

import readline

sys.ps1 = "\033[32m>>> \033[0m"
sys.ps2 = "\033[32m... \033[0m"

# Preload standard math tools
from math import *

try:
    import numpy as np
except ImportError:
    pass
from fractions import Fraction as F


# Helper functions
def frac(x, limit=10**6):
    """Convert float to nearest simple fraction."""
    return F(x).limit_denominator(limit)


def _display_as_fraction(value):
    if value is None:
        return
    # If it's a float that looks like a simple fraction, show it!
    if isinstance(value, float):
        suggestion = F(value).limit_denominator(10**6)
        # Only show the fraction if the error is tiny
        if abs(value - float(suggestion)) < 1e-12 and suggestion.denominator <= 99999:
            # print(f"{value}  # approx {suggestion}")
            print(f"\033[1;34m{suggestion}\033[0m\t({value})")  # added a little color
            return
    # 2. Handle Fractions (make them look like '3/10' instead of 'Fraction(3, 10)')
    if isinstance(value, F):
        print(f"\033[1;34m{value.numerator}/{value.denominator}\033[0m")
        return
    sys.__displayhook__(value)


sys.displayhook = _display_as_fraction

# Session Logic
session_dir = os.environ.get("SESSION_DIR")

if session_dir:
    import dill

    state_file = os.path.join(session_dir, "state.dill")
    hist_file = os.path.join(session_dir, "history")

    # 1. Restore Readline History
    if os.path.exists(hist_file):
        try:
            readline.read_history_file(hist_file)
        except Exception:
            pass
    readline.set_history_length(100000)

    # 2. Restore Python State
    if os.path.exists(state_file):
        try:
            with open(state_file, "rb") as f:
                _state = dill.load(f)
            # Apply saved state to global namespace
            globals().update(_state)
            del _state
        except Exception as exc:
            print(f"\033[31mError restoring state: {exc}\033[0m")

    # 3. Define Save Handler
    def _save_session():
        # Save History
        readline.write_history_file(hist_file)

        # Save State
        # We skip modules, functions with modules (builtins), and our own setup vars
        _skip = {
            "dill",
            "os",
            "sys",
            "math",
            "atexit",
            "readline",
            "session_dir",
            "state_file",
            "hist_file",
            "np",
            "F",
            "D",
        }

        try:
            _curr_state = {}
            for k, v in globals().items():
                if k.startswith("_") or k in _skip:
                    continue
                # Don't save modules themselves
                if (
                    hasattr(v, "__module__")
                    and v.__module__ == "builtins"
                    and k not in ["frac"]
                ):
                    continue
                if type(v).__name__ == "module":
                    continue
                _curr_state[k] = v
            with open(state_file, "wb") as f:
                dill.dump(_curr_state, f)
        except Exception as e:
            # We print to stderr because stdout is being captured by 'script'
            sys.stderr.write(f"\n\033[31mError saving state: {e}\033[0m\n")

    atexit.register(_save_session)

    # Clean up the namespace so 'calc' feels like a fresh REPL
    # We leave the math imports and 'frac' helper
