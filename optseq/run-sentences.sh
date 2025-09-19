./optseq2 --ntp 153 --tr 2 \
--psdwin 0 20 2 \
--ev crowd_language 4 4 \
--ev communication_language 4 9 \
--ev joint_language 4 9 \
--ev independent_language 4 9 \
--ev object_language 4 9 \
--tnullmin 2 \
--tnullmax 8 \
--nkeep 50 \
--o sentences \
--tsearch 0.167

rm *sum
rm *log
rm *mat
