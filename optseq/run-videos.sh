./optseq2 --ntp 126 --tr 2 \
--psdwin 0 20 2 \
--ev crowd_vision 2 5 \
--ev communication_vision 2 12 \
--ev joint_vision 2 12 \
--ev independent_vision 2 12 \
--ev object_vision 2 12 \
--tnullmin 2 \
--tnullmax 8 \
--nkeep 50 \
--o videos \
--tsearch 0.167

rm *sum
rm *log
rm *mat
