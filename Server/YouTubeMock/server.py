#!/usr/bin/env python3
"""Loopback-only deterministic HTTP fixtures for WhyTea tests.

This process deliberately has no outbound networking code. It serves the
first-party fixture contract documented in README.md; it does not impersonate
or proxy YouTube's private API.
"""

from __future__ import annotations

import argparse
import json
import signal
import threading
from dataclasses import dataclass, field
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import parse_qs, quote, unquote, urlsplit


ROOT = Path(__file__).resolve().parent
# One catalog for both fixture services: the app's in-process
# FixtureYouTubeService decodes the same file from its DEBUG bundle.
DEFAULT_FIXTURES = ROOT.parents[1] / "WhyTea" / "Shared" / "Fixtures" / "catalog.json"
SCHEMA_VERSION = 1
MAX_REQUEST_BODY = 64 * 1024
FRAME = bytes((0xFF, 0xFB, 0x18, 0xC0)) + bytes(140)
MEDIA_BYTES = FRAME * 56


def load_catalog(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        catalog = json.load(handle)
    if catalog.get("schemaVersion") != SCHEMA_VERSION:
        raise ValueError(f"unsupported fixture schema: {catalog.get('schemaVersion')!r}")
    videos = catalog.get("videos")
    if not isinstance(videos, dict) or not videos:
        raise ValueError("fixture catalog must contain videos")
    for video_id, video in videos.items():
        if len(video_id) != 11:
            raise ValueError(f"fixture video id must have 11 characters: {video_id!r}")
        if video.get("summary", {}).get("id") != video_id:
            raise ValueError(f"summary id does not match catalog key: {video_id!r}")
    return catalog


@dataclass
class Fault:
    status: int
    message: str


@dataclass
class ServerState:
    catalog: dict[str, Any]
    requests: list[dict[str, Any]] = field(default_factory=list)
    faults: dict[str, Fault] = field(default_factory=dict)
    lock: threading.Lock = field(default_factory=threading.Lock)

    def reset(self) -> None:
        with self.lock:
            self.requests.clear()
            self.faults.clear()

    def set_fault(self, operation: str, status: int, message: str) -> None:
        if operation not in {"home", "search", "suggestions", "details", "comments", "playback", "media"}:
            raise ValueError(f"unsupported operation: {operation}")
        if not 400 <= status <= 599:
            raise ValueError("fault status must be between 400 and 599")
        with self.lock:
            self.faults[operation] = Fault(status=status, message=message)

    def fault_for(self, operation: str) -> Fault | None:
        with self.lock:
            return self.faults.get(operation)

    def record(self, *, method: str, path: str, query: dict[str, list[str]], status: int, body_keys: list[str]) -> None:
        with self.lock:
            self.requests.append(
                {
                    "method": method,
                    "path": path,
                    "query": {key: values for key, values in sorted(query.items())},
                    "status": status,
                    "bodyKeys": sorted(body_keys),
                }
            )

    def request_snapshot(self) -> list[dict[str, Any]]:
        with self.lock:
            return list(self.requests)


class MockHTTPServer(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

    def __init__(self, address: tuple[str, int], catalog: dict[str, Any]):
        super().__init__(address, MockRequestHandler)
        self.state = ServerState(catalog)


class MockRequestHandler(BaseHTTPRequestHandler):
    server_version = "WhyTeaYouTubeMock/1"
    protocol_version = "HTTP/1.0"

    @property
    def mock_server(self) -> MockHTTPServer:
        return self.server  # type: ignore[return-value]

    def log_message(self, _format: str, *_args: Any) -> None:
        return

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._handle("GET")

    def do_HEAD(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._handle("HEAD", head_only=True)

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._handle("POST")

    def _handle(self, method: str, *, head_only: bool = False) -> None:
        parsed = urlsplit(self.path)
        query = parse_qs(parsed.query, keep_blank_values=True)
        body: dict[str, Any] = {}
        body_keys: list[str] = []
        if method == "POST":
            body = self._read_json_body()
            body_keys = list(body.keys())

        try:
            status, headers, payload, operation = self._route(method, parsed.path, query, body)
        except Exception as error:  # the server must return a useful fixture failure
            status = HTTPStatus.INTERNAL_SERVER_ERROR
            headers = {"content-type": "application/json; charset=utf-8"}
            payload = json.dumps({"error": {"code": "fixture_error", "message": str(error)}}).encode()
            operation = "unknown"

        self.mock_server.state.record(
            method=method,
            path=parsed.path,
            query=query,
            status=int(status),
            body_keys=body_keys,
        )
        self.send_response(status)
        for key, value in headers.items():
            self.send_header(key, value)
        self.send_header("content-length", str(len(payload)))
        self.end_headers()
        if not head_only:
            self.wfile.write(payload)

    def _read_json_body(self) -> dict[str, Any]:
        raw_length = self.headers.get("content-length", "0")
        try:
            length = int(raw_length)
        except ValueError as error:
            raise ValueError("invalid content-length") from error
        if length > MAX_REQUEST_BODY:
            raise ValueError("request body is too large")
        raw = self.rfile.read(length)
        if not raw:
            return {}
        decoded = json.loads(raw.decode("utf-8"))
        if not isinstance(decoded, dict):
            raise ValueError("request body must be a JSON object")
        return decoded

    def _route(
        self,
        method: str,
        path: str,
        query: dict[str, list[str]],
        body: dict[str, Any],
    ) -> tuple[int, dict[str, str], bytes, str]:
        if path == "/health" and method in {"GET", "HEAD"}:
            return (*self._json(HTTPStatus.OK, {"status": "ok", "service": "whytea-youtube-mock", "schemaVersion": SCHEMA_VERSION}), "health")

        if path == "/__control/requests" and method == "GET":
            return (*self._json(HTTPStatus.OK, {"requests": self.mock_server.state.request_snapshot()}), "control")

        if path == "/__control/reset" and method == "POST":
            self.mock_server.state.reset()
            return (*self._json(HTTPStatus.OK, {"status": "reset"}), "control")

        if path == "/__control/fault" and method == "POST":
            operation = str(body.get("operation", ""))
            self.mock_server.state.set_fault(operation, int(body.get("status", 503)), str(body.get("message", "fixture fault")))
            return (*self._json(HTTPStatus.OK, {"status": "faulted", "operation": operation}), "control")

        operation = self._operation(path)
        if operation:
            fault = self.mock_server.state.fault_for(operation)
            if fault:
                return (*self._json(fault.status, {"error": {"code": "injected_fault", "message": fault.message}}), operation)

        if path == "/api/v1/home" and method == "GET":
            return self._page(self._home_page(), "home")

        if path == "/api/v1/search" and method in {"GET", "POST"}:
            return self._page(self._search_page(query, body), "search")

        if path == "/api/v1/suggestions" and method in {"GET", "POST"}:
            requested = self._value(query, body, "q", "query").lower()
            suggestions = self.mock_server.state.catalog.get("suggestions", {}).get(requested)
            if suggestions is None:
                suggestions = self.mock_server.state.catalog.get("suggestions", {}).get("default", [])
            return (*self._json(HTTPStatus.OK, {"suggestions": suggestions}), "suggestions")

        if path.startswith("/api/v1/videos/"):
            return self._video_route(method, path, query)

        if path.startswith("/media/"):
            return self._media_route(method, path, query)

        return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found", "message": "fixture route not found"}}), "unknown")

    def _video_route(self, method: str, path: str, query: dict[str, list[str]]) -> tuple[int, dict[str, str], bytes, str]:
        parts = [unquote(part) for part in path.split("/") if part]
        if len(parts) < 4:
            return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found", "message": "video route not found"}}), "details")
        video_id = parts[3]
        video = self.mock_server.state.catalog.get("videos", {}).get(video_id)
        if not video:
            return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "unknown_video", "message": video_id}}), "details")
        if len(parts) == 4 and method == "GET":
            return (*self._json(HTTPStatus.OK, self._details(video_id, video)), "details")
        if len(parts) == 5 and parts[4] == "comments" and method == "GET":
            return (*self._json(HTTPStatus.OK, self._comments(video_id, video, query)), "comments")
        if len(parts) == 5 and parts[4] == "playback" and method == "GET":
            origin = self._origin()
            return (*self._json(
                HTTPStatus.OK,
                {"source": {"url": f"{origin}/media/{quote(video_id)}/master.m3u8", "kind": "hls"}},
            ), "playback")
        return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found", "message": "video route not found"}}), "details")

    def _media_route(self, method: str, path: str, query: dict[str, list[str]]) -> tuple[int, dict[str, str], bytes, str]:
        parts = [unquote(part) for part in path.split("/") if part]
        if len(parts) != 3:
            return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found", "message": "media route not found"}}), "media")
        video_id, resource = parts[1:]
        if video_id not in self.mock_server.state.catalog.get("videos", {}):
            return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "unknown_video", "message": video_id}}), "media")
        if resource == "thumbnail.svg":
            color = {"wTeaMock00Q": "#6d4aff", "wTeaMock01g": "#149b88", "wTeaMock02o": "#e16d43", "wTeaMock03w": "#c68b2d"}.get(video_id, "#4c5267")
            svg = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 9"><rect width="16" height="9" fill="{color}"/><circle cx="8" cy="4.5" r="2" fill="#ffffff" fill-opacity=".8"/></svg>\n'.encode()
            return HTTPStatus.OK, {"content-type": "image/svg+xml; charset=utf-8", "cache-control": "no-store"}, svg, "media"
        if resource == "master.m3u8":
            body = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-STREAM-INF:BANDWIDTH=32000,CODECS=\"mp4a.40.2\"\nindex.m3u8\n".encode()
            return HTTPStatus.OK, {"content-type": "application/vnd.apple.mpegurl", "cache-control": "no-store"}, body, "media"
        if resource == "index.m3u8":
            body = "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n#EXTINF:2.0,\nsegment-0.mp3\n#EXT-X-ENDLIST\n".encode()
            return HTTPStatus.OK, {"content-type": "application/vnd.apple.mpegurl", "cache-control": "no-store"}, body, "media"
        if resource == "segment-0.mp3":
            return self._range_response(MEDIA_BYTES, self.headers.get("range"))
        return (*self._json(HTTPStatus.NOT_FOUND, {"error": {"code": "not_found", "message": "media resource not found"}}), "media")

    @staticmethod
    def _operation(path: str) -> str:
        if path == "/api/v1/home":
            return "home"
        if path == "/api/v1/search":
            return "search"
        if path == "/api/v1/suggestions":
            return "suggestions"
        if path.startswith("/api/v1/videos/"):
            if path.endswith("/comments"):
                return "comments"
            if path.endswith("/playback"):
                return "playback"
            return "details"
        if path.startswith("/media/"):
            return "media"
        return ""

    def _home_page(self) -> dict[str, Any]:
        ids = self.mock_server.state.catalog.get("home", [])
        return {"videos": [self._summary(video_id) for video_id in ids], "continuationToken": None}

    def _search_page(self, query: dict[str, list[str]], body: dict[str, Any]) -> dict[str, Any]:
        requested = self._value(query, body, "q", "query").strip().lower()
        cursor = self._value(query, body, "cursor", "continuationToken")
        page_number = 0
        if cursor.startswith("search:"):
            try:
                page_number = int(cursor.rsplit(":", 1)[1])
            except ValueError:
                page_number = 0
        videos = self.mock_server.state.catalog.get("search", {}).get(requested)
        if videos is None:
            videos = list(self.mock_server.state.catalog.get("videos", {}).keys())
            if requested:
                videos = [video_id for video_id in videos if requested in self._search_text(video_id)]
        start = page_number * 2
        page = videos[start : start + 2]
        next_cursor = f"search:{quote(requested, safe='')}:{page_number + 1}" if start + len(page) < len(videos) else None
        return {"videos": [self._summary(video_id) for video_id in page], "continuationToken": next_cursor}

    def _search_text(self, video_id: str) -> str:
        video = self.mock_server.state.catalog["videos"][video_id]
        summary = video["summary"]
        return " ".join(str(summary.get(key, "")) for key in ("title", "channelName", "channelID")).lower()

    def _details(self, video_id: str, video: dict[str, Any]) -> dict[str, Any]:
        details = video.get("details", {})
        return {
            "id": video_id,
            "summary": self._summary(video_id),
            "channelAvatarURL": self._absolute_media(details.get("channelAvatarPath")),
            "subscriberCountText": details.get("subscriberCountText"),
            "viewCountText": video["summary"].get("viewCountText"),
            "publishedText": video["summary"].get("publishedText"),
            "likeCountText": details.get("likeCountText"),
            "descriptionText": details.get("descriptionText", ""),
            "commentCountText": details.get("commentCountText"),
            "commentsToken": details.get("commentsToken"),
            "related": [self._summary(related_id) for related_id in details.get("related", []) if related_id in self.mock_server.state.catalog["videos"]],
        }

    def _comments(self, video_id: str, video: dict[str, Any], query: dict[str, list[str]]) -> dict[str, Any]:
        comments = video.get("comments", [])
        cursor = self._value(query, {}, "cursor", "continuationToken")
        page_number = 0
        if cursor.endswith(":1"):
            page_number = 1
        page = comments[page_number * 2 : page_number * 2 + 2]
        next_token = f"{video_id}:comments:1" if page_number == 0 and len(comments) > 2 else None
        return {"comments": [self._comment(comment) for comment in page], "continuationToken": next_token}

    def _comment(self, comment: dict[str, Any]) -> dict[str, Any]:
        return {
            "id": comment["id"],
            "authorName": comment.get("authorName"),
            "authorAvatarURL": self._absolute_media(comment.get("authorAvatarPath")),
            "text": comment["text"],
            "publishedText": comment.get("publishedText"),
            "likeCountText": comment.get("likeCountText"),
            "replyCountText": comment.get("replyCountText"),
        }

    def _summary(self, video_id: str) -> dict[str, Any]:
        summary = self.mock_server.state.catalog["videos"][video_id]["summary"]
        result = dict(summary)
        result["thumbnailURL"] = self._absolute_media(result.pop("thumbnailPath", None))
        return result

    def _absolute_media(self, path: str | None) -> str | None:
        return f"{self._origin()}{path}" if path else None

    def _origin(self) -> str:
        return f"http://{self.headers.get('host', '127.0.0.1')}"

    @staticmethod
    def _value(query: dict[str, list[str]], body: dict[str, Any], *keys: str) -> str:
        for key in keys:
            if key in body and body[key] is not None:
                return str(body[key])
            if query.get(key):
                return query[key][0]
        return ""

    @staticmethod
    def _json(status: int, value: dict[str, Any]) -> tuple[int, dict[str, str], bytes]:
        return status, {"content-type": "application/json; charset=utf-8", "cache-control": "no-store"}, json.dumps(value, sort_keys=True).encode()

    @staticmethod
    def _page(value: dict[str, Any], operation: str) -> tuple[int, dict[str, str], bytes, str]:
        status, headers, body = MockRequestHandler._json(HTTPStatus.OK, value)
        return status, headers, body, operation

    def _range_response(self, data: bytes, range_header: str | None) -> tuple[int, dict[str, str], bytes, str]:
        if not range_header:
            headers = {"content-type": "audio/mpeg", "accept-ranges": "bytes", "cache-control": "no-store"}
            return HTTPStatus.OK, headers, data, "media"
        if not range_header.startswith("bytes="):
            return HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE, {"content-range": f"bytes */{len(data)}"}, b"", "media"
        try:
            start_text, end_text = range_header[6:].split("-", 1)
            start = int(start_text) if start_text else max(0, len(data) - int(end_text))
            end = int(end_text) if end_text else len(data) - 1
        except (TypeError, ValueError):
            return HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE, {"content-range": f"bytes */{len(data)}"}, b"", "media"
        if start < 0 or start >= len(data) or end < start:
            return HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE, {"content-range": f"bytes */{len(data)}"}, b"", "media"
        end = min(end, len(data) - 1)
        headers = {
            "content-type": "audio/mpeg",
            "accept-ranges": "bytes",
            "content-range": f"bytes {start}-{end}/{len(data)}",
            "cache-control": "no-store",
        }
        return HTTPStatus.PARTIAL_CONTENT, headers, data[start : end + 1], "media"


def create_server(host: str = "127.0.0.1", port: int = 0, fixtures: Path = DEFAULT_FIXTURES) -> MockHTTPServer:
    if host != "127.0.0.1":
        raise ValueError("YouTubeMock only binds to 127.0.0.1")
    return MockHTTPServer((host, port), load_catalog(fixtures))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=0)
    parser.add_argument("--fixtures", type=Path, default=DEFAULT_FIXTURES)
    parser.add_argument("--ready-file", type=Path)
    args = parser.parse_args()

    server = create_server(args.host, args.port, args.fixtures)
    origin = f"http://{args.host}:{server.server_address[1]}"
    if args.ready_file:
        args.ready_file.write_text(origin + "\n", encoding="utf-8")
    print(f"READY {origin}", flush=True)

    def stop(_signum: int, _frame: Any) -> None:
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
