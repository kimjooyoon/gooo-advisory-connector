# Advisory connector v1

## Purpose

Connect three released canonical bundles into a deterministic read-only portfolio graph. Producers remain independent and are never modified or gated by this repository.

## Promotion authority

Implementation is permitted only by immutable `gooo-link v0.5.0-dev` evidence with decision `CONNECTOR_PROMOTION_ELIGIBLE` and promotion state `ELIGIBLE`. Unknown or unrecognized promotion decisions fail closed.

## Output

The connector emits exactly five files: `portfolio.json`, `nodes.ndjson`, `edges.ndjson`, `unknowns.ndjson`, and `checksums.txt`. The released input currently yields four unique nodes, three edges, one shared specification anchor, and zero UNKNOWN relations.

A complete UNKNOWN input relation is preserved in `unknowns.ndjson` and lowers the connector decision to INCOMPLETE with the input relation's stage, step, reason, unknown_class, and next_operation. A missing domain lowers resolution at the input stage. A conflicting specification anchor is REFUTED.

## Effect boundary

The connector writes only to an explicit output directory. CI proves source repository writes 0, external required gates 0, current consumer branches 0, deterministic replay, and checksum drift rejection. The root README is not a conformance predecessor.
