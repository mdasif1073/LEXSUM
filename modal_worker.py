import modal

# ---- Modal app ----
app = modal.App("classroom-ai-worker")

# ---- Image (container) ----
# You can pin versions later for stability.
image = (
    modal.Image.debian_slim()
    .apt_install("ffmpeg")
    .pip_install(
        "rq>=1.16.2",
        "redis>=5.0.0",
        "sqlalchemy>=2.0.0",
        "psycopg[binary]>=3.1.0",
        "httpx>=0.27.0",
        "python-dotenv>=1.0.1",
        "pydantic-settings>=2.2.1",
        "transformers>=4.41.0",
        "accelerate>=0.31.0",
        "torch",
        "faster-whisper",
        "sentencepiece",
    )
    .add_local_dir("app", remote_path="/root/app")
)

# ---- Secrets ----
# Put REDIS_URL, DATABASE_URL, SUPABASE_*, WHISPER_MODEL, LLM_MODEL and HF_TOKEN
# inside a Modal secret named "classroom-env".
secret = modal.Secret.from_name("classroom-env")

# ---- Optional: persistent cache (recommended) ----
# This avoids re-downloading HuggingFace models every cold start.
model_cache = modal.Volume.from_name("hf-model-cache", create_if_missing=True)


@app.function(
    image=image,
    secrets=[secret],
    volumes={"/root/.cache/huggingface": model_cache},
    gpu="any",  # Modal will pick an available GPU
    max_containers=1,  # avoid overlapping workers
    timeout=60 * 60,  # plenty of time for a long job if needed
)
def run_rq_worker():
    """
    Runs an RQ worker that listens to the 'default' queue.
    """
    import sys
    if "/root" not in sys.path:
        sys.path.insert(0, "/root")
    from rq import Worker
    from app.queue import get_queue, get_redis  # uses REDIS_URL from env

    q = get_queue("default")
    w = Worker([q], connection=get_redis())
    # Burst + short idle wait keeps costs low when queue is empty.
    w.work(burst=True, max_idle_time=30, with_scheduler=False)


@app.local_entrypoint()
def main():
    run_rq_worker.remote()
