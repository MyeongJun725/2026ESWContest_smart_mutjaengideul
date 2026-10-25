#!/usr/bin/env python3
"""Measure first Korean content and complete, schema-validated local responses."""

import argparse
import http.client
import json
import time


def read_stream(response, started, emit, clock=time.monotonic):
    parts = []
    first_korean = None
    usage = None
    finish = None
    complete = False
    for line in response:
        if not line.startswith(b"data:"):
            continue
        data = line[5:].strip()
        if data == b"[DONE]":
            complete = True
            break
        packet = json.loads(data.decode("utf-8"))
        if "error" in packet:
            raise ValueError("로컬 서버가 스트리밍 오류를 반환했습니다.")
        if packet.get("usage") is not None:
            usage = packet["usage"]
        for choice in packet.get("choices", []):
            if choice.get("finish_reason") is not None:
                finish = choice["finish_reason"]
            text = choice.get("delta", {}).get("content")
            if not isinstance(text, str) or not text:
                continue
            if first_korean is None and any("가" <= char <= "힣" for char in text):
                first_korean = clock() - started
            parts.append(text)
            emit(text)
    elapsed = clock() - started
    if not complete or finish != "stop":
        raise ValueError("응답이 정상 완료되지 않았습니다.")
    result = json.loads("".join(parts))
    if (
        not isinstance(result, dict)
        or set(result) != {"reply"}
        or not isinstance(result["reply"], str)
        or not result["reply"].strip()
        or len(result["reply"]) > 90
    ):
        raise ValueError("JSON 응답 형식 검사를 통과하지 못했습니다.")
    return first_korean, elapsed, usage


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeat", type=int, choices=(1, 2), default=2)
    args = parser.parse_args()
    payload = {
        "model": "gemma4-e2b",
        "stream": True,
        "stream_options": {"include_usage": True},
        "temperature": 0,
        "max_completion_tokens": 160,
        "reasoning_effort": "none",
        "response_format": {
            "type": "json_schema",
            "json_schema": {
                "name": "safehub_reply",
                "strict": True,
                "schema": {
                    "type": "object",
                    "properties": {
                        "reply": {"type": "string", "minLength": 1, "maxLength": 90}
                    },
                    "required": ["reply"],
                    "additionalProperties": False,
                },
            },
        },
        "messages": [
            {"role": "system", "content":
             '방송을 짧은 한국어로 요약해. 시간과 사실을 바꾸지 마. '
             '{"reply":"요약"} JSON만 출력해.'},
            {"role": "user", "content":
             "오늘 오후 2시부터 4시까지 엘리베이터 운행이 중지됩니다. "
             "계단을 이용해 주세요."},
        ],
    }
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    for iteration in range(1, args.repeat + 1):
        print(f"\n측정 {iteration}/{args.repeat} 시작", flush=True)
        connection = http.client.HTTPConnection("127.0.0.1", 9379, timeout=180)
        started = time.monotonic()
        try:
            connection.request(
                "POST", "/v1/chat/completions", body,
                {"Content-Type": "application/json; charset=utf-8"},
            )
            response = connection.getresponse()
            if response.status != 200:
                raise ValueError(f"로컬 서버 HTTP {response.status}")
            first, elapsed, usage = read_stream(
                response, started, lambda text: print(text, end="", flush=True)
            )
        finally:
            connection.close()
        first_label = f"{first:.1f}초" if first is not None else "한글 출력 없음"
        print(f"\n첫 한글: {first_label} / 전체 완료: {elapsed:.1f}초")
        print("토큰:", json.dumps(usage, ensure_ascii=False))
        print("JSON_CONTRACT_OK", flush=True)


if __name__ == "__main__":
    main()
