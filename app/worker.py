from rq import Worker
from app.queue import get_queue, get_redis

if __name__ == "__main__":
    q = get_queue("default")
    w = Worker([q], connection=get_redis())
    w.work()
