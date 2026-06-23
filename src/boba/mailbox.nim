## A minimal thread-safe queue used in place of `std/channels` (which isn't
## present in this Nim build). Backs the runtime's `msgs` and `cmds` queues:
## the input/worker threads push, the event loop pops.
##
## `recvTimeout` polls on a short interval rather than using a timed condvar
## (Nim's `std/locks` has no timed `wait`); the poll granularity is well below
## one render frame so it has no perceptible latency impact.

import std/[locks, os]

type
  Mailbox*[T] = object
    lock: Lock
    items: seq[T]
    closed: bool

proc initMailbox*[T](mb: var Mailbox[T]) =
  initLock(mb.lock)
  mb.items = @[]
  mb.closed = false

proc send*[T](mb: var Mailbox[T], item: sink T) =
  acquire(mb.lock)
  mb.items.add(item)
  release(mb.lock)

proc close*[T](mb: var Mailbox[T]) =
  acquire(mb.lock)
  mb.closed = true
  release(mb.lock)

proc isClosed*[T](mb: var Mailbox[T]): bool =
  acquire(mb.lock)
  result = mb.closed
  release(mb.lock)

proc tryRecv*[T](mb: var Mailbox[T]): tuple[ok: bool, item: T] =
  ## Non-blocking pop.
  acquire(mb.lock)
  if mb.items.len > 0:
    result = (true, move(mb.items[0]))
    mb.items.delete(0)
  else:
    result.ok = false
  release(mb.lock)

proc recvTimeout*[T](mb: var Mailbox[T], ms: int): tuple[ok: bool, item: T] =
  ## Pop, waiting up to ~`ms` milliseconds. `ok=false` on timeout.
  const step = 2
  var waited = 0
  while true:
    let r = tryRecv(mb)
    if r.ok: return r
    if waited >= ms: return (false, default(T))
    sleep(step)
    waited += step
