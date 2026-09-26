from __future__ import annotations

import json
import threading
import unittest
from http.client import HTTPConnection
from urllib.parse import urlencode

from server import create_server


class YouTubeMockServerTests(unittest.TestCase):
    def test_refuses_non_loopback_bind(self) -> None:
        with self.assertRaises(ValueError):
            create_server(host="0.0.0.0")

    @classmethod
    def setUpClass(cls) -> None:
        cls.server = create_server()
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        host, port = cls.server.server_address
        cls.host = host
        cls.port = port

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def request(self, method: str, path: str, body: dict | None = None, headers: dict | None = None):
        connection = HTTPConnection(self.host, self.port, timeout=2)
        encoded = None
        request_headers = dict(headers or {})
        if body is not None:
            encoded = json.dumps(body).encode()
            request_headers.update({"content-type": "application/json", "content-length": str(len(encoded))})
        connection.request(method, path, body=encoded, headers=request_headers)
        response = connection.getresponse()
        data = response.read()
        status = response.status
        content_type = response.getheader("content-type", "")
        connection.close()
        return status, content_type, data

    def test_health_and_search_are_deterministic(self) -> None:
        self.assertEqual(self.request("GET", "/health")[0], 200)
        status, _, body = self.request("GET", "/api/v1/search?" + urlencode({"q": "swiftui"}))
        self.assertEqual(status, 200)
        page = json.loads(body)
        self.assertEqual([video["id"] for video in page["videos"]], ["wTeaMock00Q", "wTeaMock01g"])
        self.assertIsNotNone(page["continuationToken"])

        _, _, continuation_body = self.request("GET", "/api/v1/search?" + urlencode({"cursor": page["continuationToken"]}))
        continuation = json.loads(continuation_body)
        self.assertEqual([video["id"] for video in continuation["videos"]], ["wTeaMock02o", "wTeaMock03w"])

        status, _, empty_body = self.request("GET", "/api/v1/search?q=no-such-fixture")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(empty_body)["videos"], [])

    def test_details_comments_playback_and_range(self) -> None:
        status, _, body = self.request("GET", "/api/v1/videos/wTeaMock00Q")
        self.assertEqual(status, 200)
        details = json.loads(body)
        self.assertEqual(details["id"], "wTeaMock00Q")
        self.assertEqual(len(details["related"]), 2)

        status, _, body = self.request("GET", "/api/v1/videos/wTeaMock00Q/comments?cursor=wTeaMock00Q%3Acomments%3A0")
        self.assertEqual(status, 200)
        self.assertEqual(len(json.loads(body)["comments"]), 2)

        status, content_type, body = self.request("GET", "/api/v1/videos/wTeaMock00Q/playback")
        self.assertEqual(status, 200)
        self.assertIn("application/json", content_type)
        source = json.loads(body)["source"]
        self.assertTrue(source["url"].endswith("/master.m3u8"))

        status, content_type, body = self.request("GET", "/media/wTeaMock00Q/segment-0.mp3")
        self.assertEqual(status, 200)
        self.assertEqual(content_type, "audio/mpeg")
        self.assertGreater(len(body), 100)

        status, _, partial = self.request(
            "GET", "/media/wTeaMock00Q/segment-0.mp3", headers={"range": "bytes=0-31"}
        )
        self.assertEqual(status, 206)
        self.assertEqual(len(partial), 32)

    def test_fault_injection_is_local_and_resettable(self) -> None:
        status, _, _ = self.request("POST", "/__control/fault", {"operation": "search", "status": 503, "message": "offline"})
        self.assertEqual(status, 200)
        status, _, body = self.request("GET", "/api/v1/search?q=swiftui")
        self.assertEqual(status, 503)
        self.assertEqual(json.loads(body)["error"]["code"], "injected_fault")
        self.assertEqual(self.request("POST", "/__control/reset", {})[0], 200)
        self.assertEqual(self.request("GET", "/api/v1/search?q=swiftui")[0], 200)


if __name__ == "__main__":
    unittest.main()
