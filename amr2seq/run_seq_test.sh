#!/bin/sh
#If sequence to AMR
#python amr2seq.py --version 2.0 --amr2seq --train_data_dir ../train --data_dir ../dev

INPUT=$1
VERSION=$2
# clear up the parsed file
tail -n +2 $INPUT | sed 's/> //g' > $INPUT.tmp

#If AMR to sequence
python amr2seq.py --data_dir ../test --amrseq_file $INPUT.tmp --seq2amr --version $VERSION

rm $INPUT.tmp