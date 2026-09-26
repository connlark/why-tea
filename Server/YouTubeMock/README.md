# WhyTea YouTubeMock

Status: **test-only and local-only**.

This service protects development and CI from needless repeated requests to
YouTube. It is a deterministic fixture server, not a proxy, cache, API mirror,
or production backend. It has no outbound networking code and refuses
non-loopback binds.

## Run

```sh
python3 Server/YouTubeMock/server.py --port 0
```

Use `--ready-file /private/tmp/whytea-mock.ready` when a script needs to read
the selected port. The default catalog is `WhyTea/Shared/Fixtures/catalog.json`,
shared with the app's in-process `FixtureYouTubeService`; it is replaceable for
focused tests:

```sh
python3 Server/YouTubeMock/server.py \
  --fixtures WhyTea/Shared/Fixtures/catalog.json \
  --port 0 \
  --ready-file /private/tmp/whytea-mock.ready
```

## Contract

The stable endpoints are:

| Route | Purpose |
| --- | --- |
| `GET /health` | Readiness and schema version |
| `GET /api/v1/home` | Deterministic home page |
| `GET /api/v1/search?q=...&cursor=...` | Search and continuation pages |
| `GET /api/v1/suggestions?q=...` | Autocomplete suggestions |
| `GET /api/v1/videos/<id>` | Watch details and related videos |
| `GET /api/v1/videos/<id>/comments?cursor=...` | Comment pages |
| `GET /api/v1/videos/<id>/playback` | HLS-shaped playback source |
| `GET /media/<id>/master.m3u8` | Master playlist |
| `GET /media/<id>/index.m3u8` | Media playlist |
| `GET /media/<id>/segment-0.mp3` | Deterministic range-capable media bytes |
| `GET /media/<id>/thumbnail.svg` | Deterministic artwork |
| `GET /__control/requests` | Sanitized request log |
| `POST /__control/reset` | Clear faults and request log |
| `POST /__control/fault` | Inject one named operation failure |

Responses use JSON values that match the first-party `WhyTeaYouTube` concepts,
not vendored `YouTubeAPI` types. The `MockYouTubeClient` translates this
contract to the same service protocol as `YouTubeClient`.

## Fault injection

Inject a failure without restarting the process:

```sh
curl -sS -X POST http://127.0.0.1:<port>/__control/fault \
  -H 'content-type: application/json' \
  -d '{"operation":"search","status":503,"message":"fixture outage"}'
```

Supported operations are `home`, `search`, `suggestions`, `details`,
`comments`, `playback`, and `media`. Reset after the scenario with
`POST /__control/reset`.

## Safety boundary

- No route accepts a destination URL.
- No route imports a YouTube cookie, token, or account session.
- No route makes an outbound request.
- Request logs retain method, path, query, status, and JSON key names only.
- Do not point production code at this origin or add it to a TestFlight build.
