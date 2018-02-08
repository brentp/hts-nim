import hts

proc main() =

  var bam:Bam
  open(bam, "tests/HG02002.bam", index=true)
  #var bam = open_hts("/tmp/t.cram", fai="/data/human/g1k_v37_decoy.fa", index=true)

  var recs = newSeq[Record]()

  for b in bam:
    if len(recs) < 10:
        recs.add(b.copy())
    discard b.qname
  for b in recs:
      echo b, " ", b.flag.dup, " ", b.cigar
      for op in b.cigar:
          echo op, " ", op.op, " ", op.consumes.query, " ", op.consumes.reference
  for b in bam.query("6", 328, 32816675):
    discard b

when isMainModule:
  for i in 1..3000:
      echo i
      main()

