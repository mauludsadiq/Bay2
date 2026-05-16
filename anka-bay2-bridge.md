# ANKA on Bay2 — Integration Bridge Specification

How ANKA's epistemic coordination layer maps onto Bay2's operational substrate.

This document defines the formal boundary between the two systems. Bay2 provides the substrate. ANKA provides the semantics. Neither knows about the other's internals — only this bridge does.

---

## 1. ANKA Claim Envelope -> Bay2 Object

An ANKA claim envelope is a signed, content-addressed record. It maps directly to a Bay2 object.

ANKA structure:

    claim_envelope = {
      claim: { claim_space, subject, predicate, object,
               evidence_refs, issuer_node_id, timestamp_unix_secs },
      digest_hex,
      issuer_signature_hex
    }

Bay2 mapping:

    bay2_object = {
      kind:                "anka.claim",
      payload:             claim_envelope,
      author_id:           claim_envelope.claim.issuer_node_id,
      timestamp_unix_secs: claim_envelope.claim.timestamp_unix_secs
    }

Invariant: the ANKA digest_hex is preserved inside the payload and remains the canonical
claim identity. Bay2 does not recompute or override ANKA's digest. It wraps it.
The Bay2 object digest is a stable secondary identifier for storage and retrieval.

---

## 2. ANKA Gossip Event -> Bay2 Stream Entry

ANKA gossip carries a digest announcement between nodes. On Bay2, gossip becomes
a causal stream entry — each node maintains one gossip stream, causally ordered.

ANKA gossip:

    gossip_wire = {
      digest_hex, issuer_node_id, signature_hex, timestamp_unix_secs
    }

Bay2 mapping:

    stream_entry = {
      stream_id:           "anka.gossip." + node_id,
      kind:                "anka.gossip",
      payload:             gossip_wire,
      author_id:           gossip_wire.issuer_node_id,
      parent_digest:       previous_gossip_entry_digest,
      timestamp_unix_secs: gossip_wire.timestamp_unix_secs
    }

Any peer can replay the gossip stream to reconstruct a node's full announcement history.
Causal ordering means no gossip event can be silently dropped without breaking the chain.

---

## 3. ANKA Claim Space -> Bay2 PubSub Topic + Policy Namespace

An ANKA claim space is a named namespace with a declared policy (invariant/interpretive).
On Bay2, it maps to a pubsub topic and a policy namespace.

ANKA claim space:

    claim_space = {
      name:     "research.result.claims",
      category: "interpretive",
      policy:   "plural"
    }

Bay2 mappings:

    pubsub_topic      = "anka.claim." + claim_space.name
    policy_namespace  = "anka.ns."   + claim_space.name

Subscribers to "anka.claim.research.result.claims" receive all claims in that space.
Wildcard subscribers to "anka.claim.*" receive all claims across all spaces.
Publish operations are checked against the namespace policy before acceptance.

---

## 4. ANKA Witness / Challenge -> Bay2 Signed Operation

ANKA witnesses and challenges are signed attestations. On Bay2, they are signed operations
appended to the replay log — the canonical record of all epistemic events.

ANKA witness:

    witness = {
      digest_hex, witness_node_id, validation_type,
      body_digest_hex, witness_signature_hex, timestamp_unix_secs
    }

Bay2 mapping:

    operation = {
      kind:                "anka.witness",
      payload:             witness,
      author_id:           witness.witness_node_id,
      parent_op_digest:    previous_op_digest,
      timestamp_unix_secs: witness.timestamp_unix_secs
    }

ANKA challenge maps identically with kind "anka.challenge" and author_id = challenger_node_id.
Replaying the operation log from genesis reproduces the full witness and challenge history
for any claim.

---

## 5. ANKA Archive Trail -> Bay2 Replay Log

ANKA's archive records publish, witness, and challenge events per claim digest.
On Bay2, the archive trail is the replay log — every event is a signed operation.

ANKA trail entry:

    trail_entry = {
      digest_hex, event_kind, event_data, timestamp_unix_secs
    }

Bay2 mapping:

    operation = {
      kind:                "anka." + trail_entry.event_kind,
      payload:             trail_entry.event_data,
      author_id:           trail_entry.event_data.issuer or witness or challenger,
      parent_op_digest:    previous_op_digest,
      timestamp_unix_secs: trail_entry.timestamp_unix_secs
    }

The Bay2 replay log supersedes ANKA's claim_trails record. Any past state is reproducible
by replaying from genesis. snapshot_at(log, checkpoint) gives point-in-time audit.

---

## 6. ANKA Index / Checkpoint -> Bay2 Monotone Index + Replication Receipt

ANKA's shard index and Merkle checkpoints map to Bay2's monotone index and replication receipts.

ANKA shard index:

    index = { digest_index, subject_index, issuer_index, time_index }

Bay2 mapping:

    bay2_index = monotone_index indexed by:
      kind:    "anka.claim"
      author:  issuer_node_id
      time:    timestamp_unix_secs bucket
      tag:     claim_space name

ANKA Merkle checkpoint:

    checkpoint = { shard_key, merkle_root, digest_count, issuer_node_id, timestamp_unix_secs }

Bay2 mapping:

    replication_receipt = {
      holder_id:              checkpoint.issuer_node_id,
      object_digest:          checkpoint.merkle_root,
      received_at_unix_secs:  checkpoint.timestamp_unix_secs
    }

The Merkle root becomes the object being "held". Durability is queryable: how many nodes
have confirmed this shard checkpoint?

---

## 7. ANKA Economy -> Bay2 Metering

ANKA's economic layer (publish costs, witness rewards, stake/slash) maps to Bay2 metering.

ANKA operation costs:

    publish:   BASE_PUBLISH_COST + evidence_refs * 10
    witness:   reward BASE_WITNESS_REWARD
    challenge: reward BASE_CHALLENGE_REWARD
    compute:   BASE_COMPUTE_COST by exec_kind

Bay2 mapping:

    charge(meter, issuer_node_id, "object_store", { payload_size: claim_size })
    charge(meter, issuer_node_id, "stream_append", { payload_size: witness_size })
    charge(meter, issuer_node_id, "replication", { holder_count: target_holders })

ANKA's stake/slash model sits on top of Bay2 metering:
    stake  = lock_stake in ANKA economy, credit in Bay2 meter
    slash  = slash_stake in ANKA economy, debit in Bay2 meter
    reward = credit in both systems

---

## 8. ANKA Policy Node -> Bay2 Policy Namespace

ANKA's policy node enforces collapse rules per claim space. On Bay2, this is a declared
policy attached to the claim space namespace.

ANKA policy:

    policy_node enforces: { collapse_kind: "single-winner" or "plural", weights: reputation }

Bay2 mapping:

    policy = make_policy(
      policy_id:      "anka.policy." + claim_space,
      issuer_id:      policy_node_id,
      rules: [
        make_rule("allow", "*", "anka.claim." + claim_space, "read",   {}),
        make_rule("allow", validator_id, "anka.claim." + claim_space, "witness", {}),
        make_rule("deny",  "*", "anka.claim." + claim_space, "write",  {})
      ],
      default_effect: "deny"
    )

The collapse semantics (weighted, plural, single-winner) remain in ANKA's policy_node.
Bay2 enforces access control. ANKA enforces epistemic policy. The boundary is clean.

---

## Summary Mapping Table

    ANKA concept            Bay2 primitive
    ─────────────────────────────────────────────────────────────
    claim envelope          object (kind: anka.claim)
    gossip announcement     stream entry (stream: anka.gossip.{node})
    claim space             pubsub topic + policy namespace
    witness / challenge     signed operation in replay log
    archive trail           replay log
    shard index             monotone index (kind/author/time/tag)
    Merkle checkpoint       replication receipt (merkle root as object)
    publish cost            metering charge (object_store)
    witness reward          metering credit
    stake / slash           metering lock / debit
    policy node rules       Bay2 policy (allow/deny per namespace)

---

## Integration Principle

Bay2 never calls ANKA. ANKA never calls Bay2 directly — it calls the bridge.
The bridge is a thin translation layer with no business logic.
All epistemic semantics (collapse, reputation, challenge resolution) stay in ANKA.
All operational semantics (storage, delivery, replay, metering) stay in Bay2.
