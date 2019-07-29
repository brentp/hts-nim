import ./private/hts_concat

iterator hts_lines*(path:string): string {.inline.} =
  ## yield lines from a file, it can be gzipped or regular file

  var kstr = kstring_t(l:0, m: 0, s: nil)
  var hf = hts_open(cstring(path), "r")
  if hf == nil:
    raise newException(OSError, "[hts/files] couldn't open file at:" & path)
  while hts_getline(hf, cint(10), kstr.addr) >= 0:
    yield $kstr.s
  free(kstr.s)
  discard hts_close(hf)
