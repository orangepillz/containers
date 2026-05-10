#!/usr/bin/env python3

import argparse
import json
import os
import pathlib
import shutil
import subprocess
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class BridgeError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


def is_relative_to(path, parent):
    try:
        pathlib.Path(path).resolve().relative_to(pathlib.Path(parent).resolve())
        return True
    except ValueError:
        return False


def copy_path(source, destination):
    source = pathlib.Path(source)
    destination = pathlib.Path(destination)
    if source.is_dir():
        if destination.exists():
            if destination.is_dir():
                shutil.rmtree(destination)
            else:
                destination.unlink()
        shutil.copytree(source, destination)
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def command_output(argv):
    try:
        proc = subprocess.run(
            argv,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        return {"exit_code": 127, "stdout": "", "stderr": f"{argv[0]} not found\n"}

    return {
        "exit_code": proc.returncode,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }


class XcodeBridgeHandler(BaseHTTPRequestHandler):
    server_version = "xcode-bridge/1"
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - - [%s] %s\n" % (self.address_string(), self.log_date_time_string(), fmt % args))

    def send_json(self, status, payload):
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def handle_error(self, error):
        if isinstance(error, BridgeError):
            self.send_json(error.status, {"error": error.message})
        else:
            self.send_json(500, {"error": str(error)})

    def require_token(self):
        expected = self.server.bridge_token
        supplied = self.headers.get("X-Xcode-Bridge-Token", "")
        auth = self.headers.get("Authorization", "")
        if auth.startswith("Bearer "):
            supplied = auth.removeprefix("Bearer ").strip()
        if not expected or supplied != expected:
            raise BridgeError(401, "missing or invalid xcode bridge token")

    def read_json(self):
        length = int(self.headers.get("Content-Length", "0"))
        if length > 1024 * 1024:
            raise BridgeError(413, "request body is too large")
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8") or "{}")
        except json.JSONDecodeError as exc:
            raise BridgeError(400, f"invalid JSON: {exc}") from exc

    def translate_guest_path(self, value):
        if not isinstance(value, str):
            return value

        guest_mount = self.server.guest_mount
        bridge_root = str(self.server.bridge_root)

        if value == guest_mount:
            return bridge_root
        if value.startswith(guest_mount + "/"):
            return bridge_root + value[len(guest_mount):]
        return value

    def translate_host_output(self, value):
        if not isinstance(value, str):
            return value
        return value.replace(str(self.server.bridge_root), self.server.guest_mount)

    def host_bridge_path(self, value):
        translated = pathlib.Path(self.translate_guest_path(value)).resolve()
        if not is_relative_to(translated, self.server.bridge_root):
            raise BridgeError(400, f"path must be under {self.server.guest_mount}")
        return translated

    def app_container_root(self, device, bundle_id, container_kind):
        argv = ["xcrun", "simctl", "get_app_container", device, bundle_id, container_kind]
        proc = subprocess.run(argv, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if proc.returncode != 0:
            raise BridgeError(500, proc.stderr.strip() or "simctl get_app_container failed")
        return pathlib.Path(proc.stdout.strip()).resolve()

    def do_GET(self):
        try:
            self.require_token()
            if self.path != "/health":
                raise BridgeError(404, "unknown endpoint")

            payload = {
                "ok": True,
                "bridge_root": str(self.server.bridge_root),
                "guest_mount": self.server.guest_mount,
                "exchange": self.server.guest_mount + "/exchange",
                "xcode_select": command_output(["xcode-select", "-p"]),
                "xcodebuild": command_output(["xcodebuild", "-version"]),
                "macosx_sdk": command_output(["xcrun", "--show-sdk-path", "--sdk", "macosx"]),
            }
            self.send_json(200, payload)
        except Exception as exc:
            self.handle_error(exc)

    def do_POST(self):
        try:
            self.require_token()
            payload = self.read_json()

            if self.path == "/run":
                self.send_json(200, self.handle_run(payload))
            elif self.path == "/sim-read":
                self.send_json(200, self.handle_sim_read(payload))
            elif self.path == "/sim-write":
                self.send_json(200, self.handle_sim_write(payload))
            else:
                raise BridgeError(404, "unknown endpoint")
        except Exception as exc:
            self.handle_error(exc)

    def handle_run(self, payload):
        tool = payload.get("tool")
        args = payload.get("args", [])
        cwd = payload.get("cwd", self.server.bridge_root / "exchange")

        if not isinstance(args, list) or not all(isinstance(arg, str) for arg in args):
            raise BridgeError(400, "args must be a list of strings")

        allowed = {
            "xcrun": ["xcrun"],
            "xcodebuild": ["xcodebuild"],
            "simctl": ["xcrun", "simctl"],
        }
        if tool not in allowed:
            raise BridgeError(400, "tool must be one of xcrun, xcodebuild, or simctl")

        translated_args = [self.translate_guest_path(arg) for arg in args]
        translated_cwd = pathlib.Path(self.translate_guest_path(str(cwd))).resolve()
        if not is_relative_to(translated_cwd, self.server.bridge_root):
            raise BridgeError(400, f"cwd must be under {self.server.guest_mount}")

        proc = subprocess.run(
            allowed[tool] + translated_args,
            cwd=str(translated_cwd),
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )

        return {
            "exit_code": proc.returncode,
            "stdout": self.translate_host_output(proc.stdout),
            "stderr": self.translate_host_output(proc.stderr),
        }

    def handle_sim_read(self, payload):
        device = str(payload.get("device", "booted"))
        bundle_id = str(payload.get("bundle_id", ""))
        container_kind = str(payload.get("container", "data"))
        subpath = str(payload.get("subpath", "."))

        if not bundle_id:
            raise BridgeError(400, "bundle_id is required")
        if container_kind not in {"app", "data", "groups"}:
            raise BridgeError(400, "container must be app, data, or groups")

        root = self.app_container_root(device, bundle_id, container_kind)
        source = (root / subpath).resolve()
        if not is_relative_to(source, root):
            raise BridgeError(400, "subpath escapes simulator app container")
        if not source.exists():
            raise BridgeError(404, f"simulator path does not exist: {subpath}")

        destination = self.server.bridge_root / "exchange" / "downloads" / f"{bundle_id}-{container_kind}-{uuid.uuid4().hex}"
        if source.is_file() and subpath not in {"", "."}:
            destination = destination / source.name
        copy_path(source, destination)

        return {
            "path": self.translate_host_output(str(destination)),
            "source": self.translate_host_output(str(source)),
        }

    def handle_sim_write(self, payload):
        device = str(payload.get("device", "booted"))
        bundle_id = str(payload.get("bundle_id", ""))
        container_kind = str(payload.get("container", "data"))
        source = str(payload.get("source", ""))
        subpath = str(payload.get("subpath", ""))

        if not bundle_id:
            raise BridgeError(400, "bundle_id is required")
        if not source:
            raise BridgeError(400, "source is required")
        if container_kind not in {"app", "data", "groups"}:
            raise BridgeError(400, "container must be app, data, or groups")

        source_path = self.host_bridge_path(source)
        if not source_path.exists():
            raise BridgeError(404, f"bridge source does not exist: {source}")
        if subpath in {"", "."}:
            subpath = source_path.name

        root = self.app_container_root(device, bundle_id, container_kind)
        destination = (root / subpath).resolve()
        if not is_relative_to(destination, root):
            raise BridgeError(400, "subpath escapes simulator app container")
        if destination.exists() and destination.is_dir() and source_path.is_file():
            destination = destination / source_path.name

        copy_path(source_path, destination)

        return {
            "path": self.translate_host_output(str(destination)),
            "source": self.translate_host_output(str(source_path)),
        }


def main():
    parser = argparse.ArgumentParser(description="Host side Xcode bridge for the dev container")
    parser.add_argument("--root", required=True)
    parser.add_argument("--guest-mount", default="/xcode-bridge")
    parser.add_argument("--token-file", required=True)
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8378)
    args = parser.parse_args()

    bridge_root = pathlib.Path(args.root).expanduser().resolve()
    bridge_root.mkdir(parents=True, exist_ok=True)
    (bridge_root / "exchange" / "uploads").mkdir(parents=True, exist_ok=True)
    (bridge_root / "exchange" / "downloads").mkdir(parents=True, exist_ok=True)

    token_file = pathlib.Path(args.token_file).expanduser().resolve()
    bridge_token = token_file.read_text(encoding="utf-8").strip()

    server = ThreadingHTTPServer((args.bind, args.port), XcodeBridgeHandler)
    server.bridge_root = bridge_root
    server.guest_mount = args.guest_mount.rstrip("/")
    server.bridge_token = bridge_token

    print(f"xcode bridge listening on {args.bind}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
