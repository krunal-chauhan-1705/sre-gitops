Vendored langgraph-cloud 0.3.5, unpacked so templates can be patched.
Patch: templates/postgres/stateful-set.yaml probe timeoutSeconds 1 -> 5 (not configurable via values).
Re-apply after upgrading the chart.
