"""Talks to Ollama, which runs AI models on your own computer.

Python version of lib/services/local_ai_service.dart. Nothing goes to an outside
AI service, but the computer running Ollama has to be reachable and on.
Uses only the Python standard library.
"""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from urllib.parse import urlparse

DEFAULT_URL = 'http://localhost:11434'

# Best first, chosen by trying each installed model on a sales summary.
PREFERRED_MODELS = ['phi3:mini', 'qwen2.5-coder:1.5b', 'llama3.2:1b']

_LIST_TIMEOUT = 8  # seconds
# Small models on a laptop without a strong graphics card can take a while.
_WRITE_TIMEOUT = 3 * 60


class LocalAiException(Exception):
    def __init__(self, message: str):
        super().__init__(message)
        self.message = message


def normalize_url(url: str) -> str:
    clean = url.strip().rstrip('/')
    return clean if '://' in clean else f'http://{clean}'


def pick_model(installed: list[str], saved: str | None) -> str | None:
    """Keeps the saved model while it is still installed, otherwise picks the best one."""
    if saved in installed:
        return saved
    for model in PREFERRED_MODELS:
        if model in installed:
            return model
    return installed[0] if installed else None


class LocalAiService:
    def __init__(self, base_url: str = DEFAULT_URL, opener=urllib.request.urlopen):
        self.base_url = normalize_url(base_url)
        # Swappable so tests can fake the server.
        self._open = opener

    def models(self) -> list[str]:
        data = self._send(self._request('/api/tags'), _LIST_TIMEOUT)
        models = data.get('models')
        if not isinstance(models, list):
            raise LocalAiException('Unexpected reply from the AI server.')
        return [model['name'] for model in models if isinstance(model, dict) and isinstance(model.get('name'), str)]

    def generate(self, model: str, prompt: str) -> str:
        body = {
            'model': model,
            'prompt': prompt,
            'stream': False,
            'options': {'temperature': 0.2, 'num_predict': 220},
        }
        data = self._send(self._request('/api/generate', body), _WRITE_TIMEOUT)
        reply = data.get('response')
        if not isinstance(reply, str) or not reply.strip():
            raise LocalAiException('The model gave an empty reply. Try again or choose another model.')
        return reply.strip()

    def _request(self, path: str, body: dict | None = None) -> urllib.request.Request:
        url = f'{self.base_url}{path}'
        try:
            valid = bool(urlparse(url).hostname)
        except ValueError:
            valid = False
        if not valid:
            raise LocalAiException(f'“{self.base_url}” isn’t a valid address.')
        if body is None:
            return urllib.request.Request(url, method='GET')
        return urllib.request.Request(
            url,
            data=json.dumps(body).encode('utf-8'),
            headers={'Content-Type': 'application/json'},
            method='POST',
        )

    def _send(self, request: urllib.request.Request, timeout: float) -> dict:
        try:
            with self._open(request, timeout=timeout) as response:
                status, raw = response.status, response.read()
        except urllib.error.HTTPError as error:
            # Ollama replies with JSON such as {"error": "model not found"} on failures.
            status, raw = error.code, error.read()
        except Exception:
            raise LocalAiException(f'Couldn’t reach the AI server at {self.base_url}. Check that Ollama is running on that computer.') from None

        try:
            decoded = json.loads(raw.decode('utf-8'))
        except ValueError:
            raise LocalAiException(f'{self.base_url} replied, but it doesn’t look like Ollama.') from None
        if not isinstance(decoded, dict):
            raise LocalAiException(f'{self.base_url} replied, but it doesn’t look like Ollama.')
        if status != 200:
            raise LocalAiException(f"The AI server said: {decoded.get('error') or f'error {status}'}")
        return decoded
