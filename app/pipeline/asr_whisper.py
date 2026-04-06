from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

_FW_CACHE: dict[str, object] = {}
_TF_CACHE: dict[str, object] = {}


def _should_try_faster_whisper(model_name: str) -> bool:
    backend = os.getenv("WHISPER_BACKEND", "auto").lower()
    if backend in ("transformers", "hf"):
        return False
    if backend not in ("auto", "faster"):
        return False
    # Only try faster-whisper if we can map OpenAI Whisper names to a CTranslate2 model
    # (faster-whisper cannot load OpenAI HF weights directly).
    mapped = _map_faster_whisper_model(model_name)
    if model_name.startswith("openai/whisper") and mapped == model_name:
        return False
    return True


def _map_faster_whisper_model(model_name: str) -> str:
    # Optional mapping to CTranslate2 compatible models
    mapping = {
        "openai/whisper-large-v3": "Systran/faster-whisper-large-v3",
        "openai/whisper-large-v3-turbo": "Systran/faster-whisper-large-v3-turbo",
    }
    return mapping.get(model_name, model_name)


def _get_faster_whisper(model_name: str):
    if model_name in _FW_CACHE:
        return _FW_CACHE[model_name]
    from faster_whisper import WhisperModel  # type: ignore

    model = WhisperModel(model_name, device="auto", compute_type="auto")
    _FW_CACHE[model_name] = model
    return model


def _get_transformers_asr(model_name: str):
    if model_name in _TF_CACHE:
        return _TF_CACHE[model_name]
    from transformers import pipeline  # type: ignore

    # Enable chunked Whisper inference so recordings longer than ~30s can be
    # transcribed without triggering long-form generation errors.
    asr = pipeline(
        "automatic-speech-recognition",
        model=model_name,
        device_map="auto",
        chunk_length_s=30,
        stride_length_s=5,
    )
    _TF_CACHE[model_name] = asr
    return asr


def transcribe_audio_bytes(audio_bytes: bytes, model_name: str, input_name: str = "input.m4a") -> str:
    """
    Returns plain transcript text.
    Worker-side: requires either faster-whisper OR transformers+torch.
    """
    def _ffmpeg_to_wav(src_path: str, wav_path: str) -> None:
        """
        Convert any ffmpeg-decodable audio to a 16kHz mono wav for robust ASR input.
        """
        if not shutil.which("ffmpeg"):
            raise RuntimeError("ffmpeg not found in PATH")
        p = subprocess.run(
            [
                "ffmpeg",
                "-hide_banner",
                "-loglevel",
                "error",
                "-y",
                "-i",
                src_path,
                "-ac",
                "1",
                "-ar",
                "16000",
                wav_path,
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if p.returncode != 0:
            raise RuntimeError(f"ffmpeg failed ({p.returncode}): {p.stderr.strip()}")

    # Write bytes to temp files (most ASR libs want file paths)
    with tempfile.TemporaryDirectory() as tmpdir:
        ext = Path(input_name).suffix.lower()
        if not ext or len(ext) > 10:
            ext = ".m4a"
        src_path = os.path.join(tmpdir, f"input{ext}")
        wav_path = os.path.join(tmpdir, "input.wav")

        with open(src_path, "wb") as f:
            f.write(audio_bytes)

        # Prefer wav for maximum decoder compatibility (m4a/aac frequently fails without ffmpeg).
        path = src_path
        ffmpeg_error: str | None = None
        try:
            _ffmpeg_to_wav(src_path, wav_path)
            path = wav_path
        except Exception as e:
            ffmpeg_error = str(e)
            # We'll fall back to the original file and let the ASR backend try to decode it.
            pass

        # 1) Try faster-whisper (best speed)
        try:
            if _should_try_faster_whisper(model_name):
                fw_name = _map_faster_whisper_model(model_name)
                model = _get_faster_whisper(fw_name)
                segments, _info = model.transcribe(path, beam_size=1)
                text = " ".join(seg.text.strip() for seg in segments if seg.text.strip())
                return text.strip()
        except Exception:
            pass

        # 2) Fallback: transformers whisper
        asr = _get_transformers_asr(model_name)
        try:
            out = asr(path, return_timestamps=True)
        except Exception as e:
            if ffmpeg_error:
                raise RuntimeError(f"ASR decode failed (ffmpeg_convert_error={ffmpeg_error})") from e
            raise
        if isinstance(out, dict) and "text" in out:
            return str(out["text"]).strip()
        return str(out).strip()
