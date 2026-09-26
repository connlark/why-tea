# WhyTea local test services

`Server/` contains development-only services. Nothing here is shipped in the
WhyTea app, deployed as a relay, or allowed to proxy production YouTube
traffic.

## YouTubeMock

`YouTubeMock` is a loopback-only, deterministic HTTP fixture server for
package tests, SwiftUI previews, simulator flows, and failure-state work. It
does not contact YouTube. The server exposes a small WhyTea fixture contract
under `/api/v1/`, deterministic HLS-shaped media responses under `/media/`,
and test controls under `/__control/`.

Start it with:

```sh
python3 Server/YouTubeMock/server.py --port 0
```

The process prints a `READY http://127.0.0.1:<port>` line. Use the printed
origin as `WHYTEA_MOCK_BASE_URL` for the mock client and tests. The server
shuts down on `SIGTERM`/`SIGINT` and rejects non-loopback bind addresses.

Run its standard-library test suite with:

```sh
PYTHONPATH=Server/YouTubeMock python3 -m unittest discover \
  -s Server/YouTubeMock/tests -p 'test_*.py'
```

The mock is intentionally a WhyTea fixture API rather than an InnerTube clone.
That keeps test data stable when YouTube changes its private response schema.
The live `YouTubeClient` and extractor remain covered by the separately gated
`WHYTEA_LIVE=1` bakeoff.
