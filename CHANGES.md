v0.2.7
======
+ [vcf] remove deprecated FORMAT (ints, floats) and INFO (ints, floats, strings)
+ [vcf] add FORMAT.get, set(field, strings) to get and set string fields from FORMAT fields
+ [vcf] add FORMAT.fields to iterate for the FORMAT field of a VCF, the returned FormatField
        type tells the name, (v)type and number of values per sample of each field.

v0.2.5
======
+ [vcf] deprecate ints, strings, floats in favor of dispatch to `get` for both INFO and FORMAT.
