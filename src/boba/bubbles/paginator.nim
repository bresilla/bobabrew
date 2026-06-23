## A paginator — port of the core of `charmbracelet/bubbles/paginator`.
## Tracks the current page over a number of items and renders either dots or an
## "n/m" indicator.

import std/strutils
import ../tea/msg
import ../uv/key

type
  PaginatorKind* = enum pkArabic, pkDots

  Paginator* = object
    page*: int           ## zero-based current page
    perPage*: int
    totalItems*: int
    kind*: PaginatorKind
    activeDot*, inactiveDot*: string

proc newPaginator*(perPage = 10): Paginator =
  Paginator(page: 0, perPage: max(perPage, 1), totalItems: 0,
            kind: pkArabic, activeDot: "•", inactiveDot: "○")

proc totalPages*(p: Paginator): int =
  if p.totalItems <= 0: return 1
  (p.totalItems + p.perPage - 1) div p.perPage

proc onLastPage*(p: Paginator): bool = p.page >= p.totalPages - 1
proc onFirstPage*(p: Paginator): bool = p.page <= 0

proc nextPage*(p: var Paginator) =
  if not p.onLastPage: inc p.page
proc prevPage*(p: var Paginator) =
  if not p.onFirstPage: dec p.page

proc itemsOnPage*(p: Paginator, total: int): int =
  ## Number of items shown on the current page given a total count.
  if total <= 0: return 0
  let start = p.page * p.perPage
  result = min(p.perPage, max(total - start, 0))

proc sliceBounds*(p: Paginator, total: int): tuple[lo, hi: int] =
  ## [lo, hi) item indices for the current page.
  let lo = min(p.page * p.perPage, total)
  let hi = min(lo + p.perPage, total)
  (lo, hi)

proc update*(p: var Paginator, m: Msg) =
  if not (m of KeyPressMsg): return
  let k = KeyPressMsg(m).key
  if k.matchString("right", "l"): p.nextPage()
  elif k.matchString("left", "h"): p.prevPage()

proc view*(p: Paginator): string =
  case p.kind
  of pkArabic:
    $(p.page + 1) & "/" & $p.totalPages
  of pkDots:
    var dots: seq[string]
    for i in 0 ..< p.totalPages:
      dots.add (if i == p.page: p.activeDot else: p.inactiveDot)
    dots.join("")
