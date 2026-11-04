"""
The egress probe. Pennsieve runs it with:

  INPUT_DIR    the step's input files (not read)
  OUTPUT_DIR   where to write; egress.json goes to OUTPUT_DIR/results/
  URLS         comma-separated URLs to try (app.yml's default: pypi.org
               and example.com)

It GETs each URL with a 10 s timeout and records whether it answered. It
exits 0 whatever it finds: no internet is a result, not a failure (and the
app review runs it with no network). The result is also logged as one line,
EGRESS:<json>, so a test can read it from the step's log.
"""
import json
import logging
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s")
log = logging.getLogger("app")
# The Lambda runtime sets the root logger to WARNING before this runs.
log.setLevel(logging.INFO)

OUTPUTS = ("results",)
DEFAULT_URLS = "https://pypi.org/simple/,https://example.com"
TIMEOUT = 10


def probe(url, timeout=TIMEOUT):
    """What a GET of url gives: {reachable, status | error, seconds}."""
    start = time.monotonic()
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            r.read(100)
            out = {"reachable": True, "status": r.status, "finalUrl": r.geturl()}
    except Exception as e:  # noqa: BLE001 - every failure is a result
        # An HTTP error status still means the host was reached.
        status = getattr(e, "code", None)
        out = {"reachable": status is not None, "error": f"{type(e).__name__}: {e}"[:300]}
        if status is not None:
            out["status"] = status
    out["seconds"] = round(time.monotonic() - start, 2)
    return out


def main():
    output_dir = os.environ.get("OUTPUT_DIR")
    if not output_dir:
        log.error("OUTPUT_DIR must be set")
        return 2
    for name in OUTPUTS:
        os.makedirs(os.path.join(output_dir, name), exist_ok=True)
    urls = [u.strip() for u in (os.environ.get("URLS") or DEFAULT_URLS).split(",") if u.strip()]
    result = {
        "at": datetime.now(timezone.utc).isoformat(),
        "deploymentMode": os.environ.get("DEPLOYMENT_MODE"),
        "runtime": "lambda" if os.environ.get("AWS_LAMBDA_FUNCTION_NAME") else "container",
        "urls": {u: probe(u) for u in urls},
    }
    path = os.path.join(output_dir, "results", "egress.json")
    with open(path, "w") as out:
        json.dump(result, out, indent=2)
    log.info("EGRESS:%s", json.dumps(result, separators=(",", ":")))
    log.info("wrote %s", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
