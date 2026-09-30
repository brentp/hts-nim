import ./hts/utils
import ./hts/private/hts_concat

export utils
export kstring_t, free, hts_open, hts_close, hts_getline, htsFile, bcf_float_missing
import ./hts/bam
export bam
import ./hts/vcf
export vcf
import ./hts/fai
export fai
import ./hts/bgzf
export bgzf
import ./hts/bgzf/bgzi
export bgzi
import ./hts/csi
export csi
import ./hts/stats
export stats
import strutils


proc htslibVersion*(): string =
  $hts_version()

proc checkVersion() =
  var v = htslibVersion().split(".")
  doAssert v[0] == "1", ("[hts/nim] error this version of hts-nim requires htslib 1.x, got version: " & htslibVersion())
  let minor = parseInt(v[1].split({'-', '+', '~', ' '})[0]) # strip e.g. debian's "13+ds"
  doAssert minor >= 10, ("[hts/nim] error this version of hts-nim requires htslib >=1.10, got version: " & htslibVersion())

checkVersion()

when isMainModule:
  echo htslibVersion()
