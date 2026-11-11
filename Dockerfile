FROM python:3.12-slim

WORKDIR /processor

# ---------------------------------------------------------------------------
# Build-time probe (branch build-probe): what can a Dockerfile RUN step see
# and reach while the App Store builds it? Each line is prefixed PROBE: so
# the CodeBuild log can be grepped. Nothing here is kept in the image.
# ---------------------------------------------------------------------------
RUN python3 - <<'PY'
import os, socket, subprocess, urllib.request, urllib.error

def say(k, v):
    print(f"PROBE: {k}: {v}", flush=True)

def get(url, timeout=3, method="GET", headers=None):
    try:
        req = urllib.request.Request(url, method=method, headers=headers or {})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return f"HTTP {r.status} {r.read(200)!r}"
    except urllib.error.HTTPError as e:
        return f"HTTP {e.code}"
    except Exception as e:
        return f"unreachable ({type(e).__name__}: {e})"

say("hostname", socket.gethostname())
say("pid1", open("/proc/1/comm").read().strip())
say("env", sorted(k for k in os.environ))
say("env AWS_*", {k: ("<set>" if v else "") for k, v in os.environ.items() if k.startswith("AWS_")})
try:
    say("pid1 environ keys", sorted(x.split("=", 1)[0] for x in open("/proc/1/environ", "rb").read().decode(errors="replace").split("\0") if x))
except Exception as e:
    say("pid1 environ", f"unreadable ({e})")
say("ec2 imds v1", get("http://169.254.169.254/latest/meta-data/"))
say("ec2 imds v2 token", get("http://169.254.169.254/latest/api/token", method="PUT", headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"}))
say("container creds root", get("http://169.254.170.2/"))
say("container creds v2", get("http://169.254.170.2/v2/credentials/"))
say("buildkit socket", os.path.exists("/run/buildkit/buildkitd.sock"))
say("docker socket", os.path.exists("/var/run/docker.sock"))
say("internet https", get("https://example.com/", timeout=5))
say("internet pypi", get("https://pypi.org/simple/pip/", timeout=5))
try:
    say("interfaces", subprocess.run(["sh", "-c", "cat /proc/net/dev | tail -n +3 | awk '{print $1}' | tr '\\n' ' '"], capture_output=True, text=True).stdout.strip())
    say("routes", subprocess.run(["sh", "-c", "cat /proc/net/route | tail -n +2 | awk '{print $1, $2, $3}' | tr '\\n' ';'"], capture_output=True, text=True).stdout.strip())
    say("mounts", subprocess.run(["sh", "-c", "cat /proc/self/mounts | awk '{print $2}' | head -40 | tr '\\n' ' '"], capture_output=True, text=True).stdout.strip())
    say("processes", subprocess.run(["sh", "-c", "ls /proc | grep -E '^[0-9]+$' | wc -l"], capture_output=True, text=True).stdout.strip())
    say("uid", os.getuid())
except Exception as e:
    say("subprocess", f"failed ({e})")
PY

# The Lambda runtime interface client, for running as a Lambda function.
RUN pip install --no-cache-dir awslambdaric==2.2.1

COPY processor/ /processor/processor/

ENV PYTHONPATH="/processor"

# Runs main() once as a container, or serves processor.handler as a Lambda
# function (see processor/entry.py).
ENTRYPOINT ["python3", "-m", "processor.entry"]
