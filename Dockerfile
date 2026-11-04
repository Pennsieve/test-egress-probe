FROM python:3.12-slim

WORKDIR /processor

# The Lambda runtime interface client, for running as a Lambda function.
RUN pip install --no-cache-dir awslambdaric==2.2.1

COPY processor/ /processor/processor/

ENV PYTHONPATH="/processor"

# Runs main() once as a container, or serves processor.handler as a Lambda
# function (see processor/entry.py).
ENTRYPOINT ["python3", "-m", "processor.entry"]
