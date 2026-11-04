.PHONY: help test run clean

.DEFAULT: help

help:
	@echo "make test   - run the probe with Python (no Docker), writing to data/output/"
	@echo "make run    - run it in Docker, writing to data/output/"
	@echo "make clean  - remove data/output/"

test: clean
	INPUT_DIR=sample-input OUTPUT_DIR=data/output python3 -m processor.main
	@cat data/output/results/egress.json

run: clean
	docker compose down --remove-orphans
	docker compose build
	docker compose up --exit-code-from processor

clean:
	rm -rf data/output
