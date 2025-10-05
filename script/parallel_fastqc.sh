#!/bin/bash
set -euo pipefail

# Usage: parallel_fastqc.sh <WDIR> <CPUS>
WDIR=${1:-.}
CPUS=${2:-4}

OUTDIR="$WDIR/FastQC"
mkdir -p "$OUTDIR"

shopt -s nullglob
for i in *.fastq.gz; do
  while [ "$(jobs -r | wc -l)" -ge "$CPUS" ]; do sleep 2; done
  echo "fastqc: Gathering sequencing metrics for sample $i"
  echo "command: fastqc -q -o \"$OUTDIR\" \"$i\""
  fastqc -q -o "$OUTDIR" "$i" &
done
wait
shopt -u nullglob

#echo "Running MultiQC on $OUTDIR"
#multiqc -m fastqc "$OUTDIR" -o "$OUTDIR"

echo "ALL FASTQC & MULTIQC PROCESSING IS DONE! Results in: $OUTDIR"