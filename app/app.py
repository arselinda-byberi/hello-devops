"""Tiny status service used to demonstrate a full build -> deploy pipeline."""
import os
import socket
import time

from flask import Flask, jsonify

app = Flask(__name__)

START_TIME = time.time()
APP_VERSION = os.getenv("APP_VERSION", "dev")
ENVIRONMENT = os.getenv("APP_ENV", "local")


@app.get("/")
def index():
    return jsonify(
        message="Hello from the DevOps portfolio project",
        version=APP_VERSION,
        environment=ENVIRONMENT,
        hostname=socket.gethostname(),  # shows which pod answered
    )


@app.get("/healthz")
def healthz():
    """Liveness probe: the process is up."""
    return jsonify(status="ok")


@app.get("/readyz")
def readyz():
    """Readiness probe: the app is ready to receive traffic."""
    return jsonify(status="ready", uptime_seconds=round(time.time() - START_TIME, 1))


@app.get("/version")
def version():
    return jsonify(version=APP_VERSION)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
