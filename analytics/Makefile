# Triad Protocol analytics pipeline. Run from analytics/.
# The sample and the full baselines go to separate warehouses: both contain a greedy
# seed-1 run with different ids, so loading them together would double-count it.
UV ?= uv
DBT = $(UV) run dbt
DBT_ARGS = --project-dir dbt --profiles-dir dbt
SAMPLE_DB = $(CURDIR)/warehouse/sample.duckdb
FULL_DB = $(CURDIR)/warehouse/triad.duckdb

.PHONY: sync lint sample full test docs clean

sync:
	$(UV) sync

lint:
	$(UV) run ruff check src tests
	$(UV) run ruff format --check src tests

sample: ## ingest the committed 20-run sample and build + test every model
	$(UV) run triad-ingest --input 'data/sample/*.jsonl' --db $(SAMPLE_DB)
	TRIAD_DUCKDB_PATH=$(SAMPLE_DB) $(DBT) build $(DBT_ARGS)

full: ## ingest the git-ignored 500-run simulator baselines and build + test
	$(UV) run triad-ingest --input 'data/raw/sim/*.jsonl' --db $(FULL_DB)
	TRIAD_DUCKDB_PATH=$(FULL_DB) $(DBT) build $(DBT_ARGS)

test: ## pytest: ingest idempotency + mart numbers vs. independent counts from the JSONL
	$(UV) run pytest

docs: ## dbt docs site for the sample warehouse
	TRIAD_DUCKDB_PATH=$(SAMPLE_DB) $(DBT) docs generate $(DBT_ARGS)

clean:
	rm -rf warehouse dbt/target dbt/logs
