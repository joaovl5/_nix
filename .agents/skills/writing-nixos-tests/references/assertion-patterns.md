# Assertion patterns for NixOS VM tests

Good integration tests prove behavior with observable evidence. A command's exit code is often only one piece of evidence.

## Positive network assertion

Use a unique token and assert it arrives at the expected listener with the expected source.

```python
token = _token("example")
assert token in _tcp_roundtrip(client, SERVICE_IP, SERVICE_PORT, token, family="4")
_assert_log_has_entry(server, _log_path("example"), token, EXPECTED_SOURCE_IP)
```

This proves:

- the client reached the intended service;
- the listener was alive;
- the response belongs to this attempt;
- the source address/path is the one under test.

## Negative network assertion

Use a control/preflight before trusting absence.

```python
_assert_denied_listener_preflight(
    machine=server,
    log_path=_log_path("denied-listener"),
    control_command=_python_network_command(... token=control_token ...),
    blocked_command=_python_network_command(... token=blocked_token ...),
    control_token=control_token,
    blocked_token=blocked_token,
    message="Blocked path must not reach denied listener",
    blocked_machine=client,
)
```

Required evidence:

1. control token reaches the listener;
2. listener log is cleared;
3. blocked command fails or times out;
4. blocked token is absent.

Listener-health contract:

- TCP control should complete a connection, send a unique token, receive either the token or an expected body, and write the token/source to the listener log.
- UDP control should send a unique token, receive an echo or expected datagram response, and write the token/source to the listener log.
- If the control/preflight fails, the assertion should fail with a message naming the listener/control path, not the blocked path. A broken control means the test has no evidence that later log absence is meaningful.
- Use separate control and blocked tokens; never reuse a token across attempts.

## One-way limitation assertion

Sometimes a current flaw is more precise than a simple block. For example, a UDP packet may reach a namespace listener but the response may not return.

When the test intentionally documents that limitation:

- keep the blocked client command failing;
- assert the blocked token appears in the listener log;
- add an inline narrative comment explaining this is a current limitation, not a desired success path;
- make the assertion message name the limitation.

## Fail-closed assertion

A fail-closed test should prove no fallback path exists.

Examples of evidence:

- the confined service fails to start while the namespace/VPN is unavailable;
- no output file is written by the confined service;
- a probe observer was preflighted, cleared, and did not receive the blocked token;
- plain/non-confined services still use their expected direct source, if that distinction matters;
- recovery after restoring the dependency is explicitly tested.

## Restart/idempotency assertion

A restart test should prove more than `systemctl restart` returning zero.

Useful evidence:

- functional traffic still passes after restart;
- fail-closed and DNS checks still pass after restart;
- namespace existence is not duplicated;
- firewall/NAT rules do not duplicate;
- listeners that bind inside a recovered namespace are restarted or otherwise proven active.

## Common weak assertions

Avoid these unless paired with stronger evidence:

- `curl` failure as the only proof of a blocked path;
- empty log as the only proof of no packet leak;
- `systemctl start` success as the only proof of service readiness;
- `ping` as the only proof of WireGuard readiness;
- route output checked only for a present token, with no excluded fallback route;
- a passing command that does not prove source identity.
