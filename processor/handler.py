"""
The Lambda runtime. A Lambda step's payload carries inputDir, outputDir and
the step's parameters as fields (a container gets them as environment
variables); the handler sets those variables and runs the same main(), so
both runtimes do the same work. Nothing to change here when you add a
parameter: every UPPER_CASE field of the payload becomes a variable.
"""
import os
import re

from processor import main as app

PARAMETER = re.compile(r"^[A-Z][A-Z0-9_]*$")

# The parameters the previous invocation set: a warm function keeps its
# environment, so those are cleared first. Only those: the runtime's own
# variables (AWS_LAMBDA_*, the credentials) stay.
_previous = set()


def handler(event, context):
    os.environ["INPUT_DIR"] = event.get("inputDir") or ""
    os.environ["OUTPUT_DIR"] = event.get("outputDir") or ""
    for name in _previous:
        os.environ.pop(name, None)
    _previous.clear()
    for name, value in event.items():
        if PARAMETER.match(name) and value is not None:
            os.environ[name] = str(value).lower() if isinstance(value, bool) else str(value)
            _previous.add(name)
    code = app.main()
    if code != 0:
        # An exception fails the step; a returned value would succeed.
        raise RuntimeError(f"the app exited with {code}")
    return {"status": "ok", "outputDir": os.environ["OUTPUT_DIR"]}
