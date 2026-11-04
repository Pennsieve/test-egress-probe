# test-egress-probe

A test app for the compute node test matrix (compute-node-aws-provisioner-v2,
`test/e2e`, row `batch-offline`). As a workflow step it GETs each URL in
`URLS` (default https://pypi.org/simple/ and https://example.com) with a 10 s
timeout, writes `OUTPUT_DIR/results/egress.json`, and logs the same result as
one line `EGRESS:<json>`:

```
{"at": "...", "deploymentMode": "compliant", "runtime": "container",
 "urls": {"https://example.com": {"reachable": false, "error": "URLError: ...", "seconds": 10.0}, ...}}
```

A URL is `reachable` when it answered at all (an HTTP error status counts).
The app exits 0 either way: no internet is the result, not a failure.

It runs on `standard` (an ECS task) and `lambda` (the image serves both,
`processor/entry.py`).

```
make test   # with Python, into data/output/
make run    # in Docker
```
