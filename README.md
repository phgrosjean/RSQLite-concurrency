# RSQLite-concurrency

Experiment with concurrency in (R)SQLite. RSQLite is not designed for concurrent writing, but concurrent reading should be fine. However, with a little bit of clever code, one can haves several processes writnig almost simultaneously in a safe way.
