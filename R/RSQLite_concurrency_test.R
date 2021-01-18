# Adapted from https://github.com/r-dbi/RSQLite/issues/56
require(DBI)
require(parallel)

dbpath <- "db/database.sqlite" # or tempfile()
con <- dbConnect(RSQLite::SQLite(), dbname = dbpath)
# SQLite can work in two modes: Journaling or WAL (Write-Ahead-Log)
# Journaling is set by default, but WAL is better for concurrency
# See: https://sqlite.org/wal.html
# - Faster (but 1-2% slower for reading only)
# - Readers do not block writers and a writer does not block readers
# But:
# - All process must be on the same computer (not over a network system)
# - Quasi-persistent -wal and -shm associated files

# You need to set WAL only once, and it remains for the db forever
dbClearResult(dbSendQuery(con, "PRAGMA journal_mode=WAL;"))
df <- data.frame(value = 0)
dbWriteTable(con, "test", df)

write.one.value <- function(val) {
  con <- dbConnect(RSQLite::SQLite(), dbname = dbpath)
  on.exit(dbDisconnect(con))

  dbWriteTable(con, "test", data.frame(value = val), append = TRUE)
}
lapply(1:20, write.one.value)
dbReadTable(con, "test")

# All fail with: Error : database is locked\n in journaled mode
# Only core #2 operations failed in WAL mode
mclapply(21:30, write.one.value, mc.cores = 2)

# This seems to work
write.one.value.concurrent <- function(val) {
  con <- dbConnect(RSQLite::SQLite(), dbname = dbpath)
  res <- dbSendQuery(con, "PRAGMA busy_timeout=5000;")
  dbClearResult(res)
  on.exit(dbDisconnect(con))

  # TODO: add a large timeout here (30 sec, or so?)
  # + what to do in case we reach it?
  repeat {
    rv <- try(dbWriteTable(con, "test", data.frame(value = val),
      append = TRUE))
    if (!is(rv, "try-error")) break
  }
  rv
}

#dbClearResult(dbSendQuery(con, "DELETE FROM test"))
dbRemoveTable(con, "test")
dbWriteTable(con, "test", df)
mclapply(1:20, write.one.value.concurrent, mc.cores = 4)
# Note, not necessarily in the right order with WAL!
# With journaling, it is very slow; with WAL still very fast!
dbReadTable(con, "test")

# Reading concurrency with writing
