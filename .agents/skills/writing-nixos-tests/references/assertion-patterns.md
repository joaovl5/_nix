# Assertion patterns for NixOS VM tests

Good integration tests prove behavior with observable evidence. Exit status is often only one piece of that proof

## Positive network assertion

- **Pattern:** use a unique token and assert it reaches the expected listener from the expected source

```python
token = _token("example")
assert token in _tcp_roundtrip(client, SERVICE_IP, SERVICE_PORT, token, family="4")
_assert_log_has_entry(server, _log_path("example"), token, EXPECTED_SOURCE_IP)
```

This proves:

- **Target reached:** the client hit the intended service
- **Listener alive:** the listener was running during the attempt
- **Attempt identity:** the response belongs to this specific probe
- **Source identity:** the source path or address matches the behavior under test

## Negative network assertion

- **Pattern:** use a control or preflight before trusting absence

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

- **Control passes:** the control token reaches the listener
- **Log reset:** clear the listener log before the blocked attempt
- **Blocked action fails:** the blocked command fails or times out
- **Blocked token absent:** the blocked token never appears in the listener log

Listener-health contract:

- **TCP control:** complete a connection, send a unique token, receive the token or expected body, and log the token plus source
- **UDP control:** send a unique token, receive an echo or expected datagram response, and log the token plus source
- **Control failure meaning:** if control fails, fail the assertion with a message about the listener or control path because later absence is no longer meaningful
- **Token separation:** use different control and blocked tokens

## One-way limitation assertion

- **When useful:** a current flaw can be more precise than a simple block
- **Example:** a UDP packet may reach a namespace listener while the response still cannot return

When intentionally documenting that limitation:

- **Client still fails:** keep the blocked client command failing
- **Listener still sees it:** assert the blocked token appears in the listener log
- **Narrate the flaw:** add an inline comment saying this is a current limitation, not a success path
- **Name it directly:** make the assertion message describe the limitation

## Fail-closed assertion

- **Goal:** prove there is no fallback path

Useful evidence:

- **Startup failure:** the confined service fails to start while the namespace or VPN is unavailable
- **No side effect:** no output file is written by the confined service
- **Observer proof:** a preflighted probe is cleared and still does not receive the blocked token
- **Direct-path contrast:** plain or non-confined services still use their expected direct source when that distinction matters
- **Recovery proof:** restoring the dependency and rechecking behavior is part of the test

## Restart and idempotency assertion

- **Goal:** prove more than `systemctl restart` returning zero

Useful evidence:

- **Traffic still works:** functional traffic still passes after restart
- **Guards still hold:** fail-closed and DNS checks still pass after restart
- **Namespace count stable:** namespace existence is not duplicated
- **Rules stay clean:** firewall or NAT rules do not duplicate
- **Recovered listeners:** listeners inside a recovered namespace are restarted or otherwise proven active

## Common weak assertions

Avoid these unless paired with stronger evidence:

- **Bare curl failure:** `curl` failure as the only proof of a blocked path
- **Bare empty log:** empty log as the only proof of no packet leak
- **Bare unit start:** `systemctl start` success as the only proof of readiness
- **Bare ping:** `ping` as the only proof of WireGuard readiness
- **Bare route token:** route output checked only for a present token with no excluded fallback route
- **Bare success:** a passing command that does not prove source identity
