# ADR 0005: Declarative automation AST and durable execution

Status: Accepted

## Context

Wizard, flow, and structured editors must share one lossless model. Delays and acknowledgements must survive crashes, and decisions must be explainable.

## Decision

Store a versioned declarative AST with stable node IDs and optional graph layout. Compile validated revisions into immutable plans. Persist runs, waits, timers, inbox/outbox, and causal trace spans in the operational store. Provide explicit concurrency, retry, debounce, cooldown, and restart semantics.

## Consequences

Rules can be tested deterministically and rendered in multiple editors. Unsupported advanced constructs make the wizard read-only rather than lossy. New node kinds require schema migration and compatibility policy.

## Alternatives

Swift closures cannot serialize or inspect safely. Arbitrary scripts weaken security and explanation. A visual graph alone lacks clear execution semantics.
