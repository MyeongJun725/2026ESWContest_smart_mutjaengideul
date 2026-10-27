import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import time

from classifier import FireTextClassifier, summarize_context


def main():
    parser = argparse.ArgumentParser(
        description="Loopback-only fastText context adapter; no Gemma/LLM"
    )
    parser.add_argument("--model", required=True)
    parser.add_argument("--port", type=int, default=9380)
    args = parser.parse_args()
    import fasttext
    classifier = FireTextClassifier(fasttext.load_model(args.model))

    class Handler(BaseHTTPRequestHandler):
        def reply(self, status, data):
            body = json.dumps(data, ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path != "/health":
                self.reply(404, {"error": "not found"})
                return
            self.reply(
                200,
                {
                    "engine": "fasttext",
                    "model": "fire-screen",
                    "labels": classifier.model.get_labels(),
                    "llm": False,
                },
            )

        def do_POST(self):
            try:
                self.connection.settimeout(3)
                length = int(self.headers.get("Content-Length", "0"))
                if not 0 < length <= 32768:
                    raise ValueError("invalid request size")
                data = json.loads(self.rfile.read(length))
                if not isinstance(data, dict):
                    raise ValueError("request must be an object")
                if self.path == "/classify":
                    self.reply(200, classifier.classify(data.get("text", "")))
                    return
                if self.path != "/v1/chat/completions":
                    self.reply(404, {"error": "not found"})
                    return
                content = data["messages"][-1]["content"]
                payload = json.loads(content)
                if not isinstance(payload, dict):
                    raise ValueError("context must be an object")
                reply = summarize_context(payload, classifier)
                self.reply(
                    200,
                    {
                        "model": "fasttext-fire-screen",
                        "choices": [
                            {
                                "message": {
                                    "role": "assistant",
                                    "content": json.dumps(
                                        {"reply": reply[:90]}, ensure_ascii=False
                                    ),
                                }
                            }
                        ],
                    },
                )
            except (ValueError, KeyError, IndexError, TypeError, AttributeError, TimeoutError) as error:
                self.reply(400, {"error": str(error)})

        def log_message(self, pattern, *args):
            # Do not log captions, API keys, or full context.
            print("fasttext request", self.command, self.path, flush=True)

    server = HTTPServer(("127.0.0.1", args.port), Handler)
    server.timeout = 2
    print("fastText ready; no generative language model loaded", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
