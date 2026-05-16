# Bay2

**The operational substrate for AI-operated systems.**

![Tests](https://img.shields.io/badge/tests-120%20passing-brightgreen)
![Lines](https://img.shields.io/badge/lines-1%2C316-blue)
![Language](https://img.shields.io/badge/language-Fard-purple)

Written in [Fard](https://github.com/mauludsadiq/FARD).

---

## The Stack

Bay2 is to ANKA what TCP/IP is to HTTP. It handles storage, transport, streaming, capabilities, and replication. ANKA handles epistemic coordination, witnessing, and truth collapse above it.

    Bay2          <- operational substrate
      |
    ANKA          <- epistemic coordination
      |
    AI systems    <- applications

---

## What Bay2 Does

| Primitive | What it provides |
|-----------|-----------------|
| Object | Digest-addressed immutable storage. The digest is not a pointer, it is the object identity. |
| Stream | Causal append-only event log. Each entry references its predecessor. Replay is deterministic. |
| Capability | Scoped bearer tokens. Attenuatable — holders can issue sub-capabilities with equal or narrower scope, never broader. |
| PubSub | Pattern-matched subscriptions. Bandwidth proportional to subscription scope, not total activity. |
| Monotone Index | Append-only indexes by kind, author, time bucket, and tag. Merge without conflict. |
| Materialized Views | Filter and count projections maintained incrementally over object streams. |
| Replication | Signed receipts. Durability queryable per object. Slashing possible for dropped objects. |
| Policy | Declared allow/deny rules. No ambient authority. Deny overrides allow. Namespace-scoped. |
| Deterministic Replay | Operation log with chain verification. Given initial state and log, reproduce any past state exactly. |
| Economic Metering | Compute and storage costs per operation. Budget tracking, charge log, usage reports. |

---

## What Bay2 Does Not Do

Bay2 does not know about claims, witnesses, reputation, or epistemic collapse. That is ANKA's domain. Bay2 provides the substrate. ANKA provides the coordination semantics.

Without Bay2:

    AI -> API -> database -> queue -> webhook -> cache -> auth layer

With Bay2:

    AI -> signed operation -> canonical object -> replicated stream

Bay2 removes implicit mutable state, ambient authority, non-verifiable queues, opaque coordination, hidden side effects, and identity ambiguity. Everything becomes digest-addressed, signed, replayable, causal, monotone, and verifiable.

---

## Running the Server

    mkdir -p out/bay2
    fardrun run --program bay2/src/server.fard --out out/bay2

The server starts on port 19000. Endpoints: POST /object, GET /object/{digest}, GET /objects, GET /replay, POST /meter/credit, POST /meter/charge, POST /pubsub/subscribe, POST /pubsub/publish, GET /summary.

## Running the Tests

    fardrun test --program bay2/tests/test_object.fard
    fardrun test --program bay2/tests/test_stream.fard
    fardrun test --program bay2/tests/test_capability.fard
    fardrun test --program bay2/tests/test_pubsub.fard
    fardrun test --program bay2/tests/test_monotone_index.fard
    fardrun test --program bay2/tests/test_view.fard
    fardrun test --program bay2/tests/test_replication.fard
    fardrun test --program bay2/tests/test_policy.fard
    fardrun test --program bay2/tests/test_replay.fard
    fardrun test --program bay2/tests/test_metering.fard
