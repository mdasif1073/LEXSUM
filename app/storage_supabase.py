from __future__ import annotations

import mimetypes
from typing import Optional

import httpx

from .config import settings


class SupabaseStorage:
    """
    Minimal Supabase Storage REST client (server-side).
    Uses service role key -> keep it ONLY in backend.
    """
    async def download_bytes(self, bucket: str, object_path: str) -> bytes:
        """
        Download object bytes using server credentials.

        Note: we can use signed URLs too, but direct download is simpler and avoids
        any signed-token edge cases. Service role key should have access to all
        storage objects in the project.
        """
        url = f"{self.base_url}/storage/v1/object/{bucket}/{object_path}"
        async with httpx.AsyncClient(timeout=120) as client:
            r = await client.get(url, headers=self._headers())
            if r.status_code >= 400:
                raise RuntimeError(f"Download failed: {r.status_code} {r.text}")
            return r.content

    def __init__(self) -> None:
        self.base_url = settings.SUPABASE_URL.rstrip("/")
        self.key = settings.SUPABASE_SERVICE_ROLE_KEY

    def _headers(self, content_type: Optional[str] = None) -> dict:
        h = {
            "Authorization": f"Bearer {self.key}",
            "apikey": self.key,
        }
        if content_type:
            h["Content-Type"] = content_type
        return h

    async def upload_bytes(
        self,
        bucket: str,
        object_path: str,
        data: bytes,
        content_type: Optional[str] = None,
        upsert: bool = True,
    ) -> str:
        """
        Uploads bytes to: storage/v1/object/{bucket}/{path}
        Returns the stored object path.
        """
        ct = content_type or mimetypes.guess_type(object_path)[0] or "application/octet-stream"
        url = f"{self.base_url}/storage/v1/object/{bucket}/{object_path}"

        params = {"upsert": "true" if upsert else "false"}

        async with httpx.AsyncClient(timeout=60) as client:
            r = await client.post(url, params=params, headers=self._headers(ct), content=data)
            if r.status_code >= 400:
                raise RuntimeError(f"Supabase upload failed: {r.status_code} {r.text}")

        return object_path

    async def create_signed_url(self, bucket: str, object_path: str, expires_in: int = 600) -> str:
        """
        Creates a signed URL (temporary access).
        POST /storage/v1/object/sign/{bucket}/{path}
        Body: { "expiresIn": 600 }
        """
        url = f"{self.base_url}/storage/v1/object/sign/{bucket}/{object_path}"
        payload = {"expiresIn": expires_in}

        async with httpx.AsyncClient(timeout=30) as client:
            r = await client.post(url, headers=self._headers("application/json"), json=payload)
            if r.status_code >= 400:
                raise RuntimeError(f"Signed URL failed: {r.status_code} {r.text}")

        # Response contains {"signedURL": "..."} (relative path)
        signed = r.json().get("signedURL")
        if not signed:
            raise RuntimeError("Supabase did not return signedURL")

        # Convert to absolute URL. Supabase may return:
        # - "/storage/v1/object/sign/..."
        # - "/object/sign/..."
        # - "object/sign/..."
        # - full absolute URL
        if str(signed).startswith("http://") or str(signed).startswith("https://"):
            return str(signed)
        s = str(signed)
        if s.startswith("/storage/v1/"):
            return f"{self.base_url}{s}"
        if s.startswith("/"):
            return f"{self.base_url}/storage/v1{s}"
        return f"{self.base_url}/storage/v1/{s}"
