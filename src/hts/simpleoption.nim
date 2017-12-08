# copied from nim lib/pure/options.nim
# this is a simplified options module with inlined methods.
import typetraits

type
  Option*[T] = object
    ## An optional type that stores its value and state separately in a boolean.
    val: T
    has: bool

proc some*[T](val: T): Option[T] {.inline.} =
  ## Returns a ``Option`` that has this value.
  result.has = true
  result.val = val

proc none*(T: typedesc): Option[T] {.inline.} =
  ## Returns a ``Option`` for this type that has no value.
  result.has = false

proc isSome*[T](self: Option[T]): bool {.inline.} =
  self.has

proc isNone*[T](self: Option[T]): bool {.inline.} =
  not self.has

proc get*[T](self: Option[T]): T {.inline.} =
  ## Returns contents of the Option. If it is none, then an exception is
  ## thrown.
  if self.isNone:
    raise newException(KeyError, "Can't obtain a value from a `none`")
  self.val

proc get*[T](self: Option[T], otherwise: T): T {.inline.} =
  ## Returns the contents of this option or `otherwise` if the option is none.
  if self.has:
    self.val
  else:
    otherwise

proc `==`*(a, b: Option): bool {.inline.} =
  ## Returns ``true`` if both ``Option``s are ``none``,
  ## or if they have equal values
  result = (a.has and b.has and a.val == b.val) or (not a.has and not b.has)


proc `$`*[T]( self: Option[T] ): string {.inline.} =
  ## Returns the contents of this option or `otherwise` if the option is none.
  if self.has:
    "Some(" & $self.val & ")"
  else:
    "None[" & T.name & "]"
