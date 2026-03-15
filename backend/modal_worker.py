import os
import sys

# Allow running this wrapper, while keeping the real Modal app at repo root.
repo_root = os.path.dirname(os.path.dirname(__file__))
if repo_root not in sys.path:
    sys.path.insert(0, repo_root)

from modal_worker import *  # noqa: F401,F403
