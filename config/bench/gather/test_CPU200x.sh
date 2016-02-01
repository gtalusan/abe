#!/bin/bash
set -ue

function generate_subbenchmark {
  min_mult=$((RANDOM % 5 + 95)) #95 - 99
  max_mult=$((RANDOM % 5 + 1)) #1 - 5

  median=${RANDOM}.${RANDOM}
  min=`echo "scale=6; ${median} * 0.${min_mult}" | bc -l`
  max=`echo "scale=6; ${median} * 1.0${max_mult}" | bc -l`

  runtime=(${min} ${median} ${max})
  base_multiplier=$((RANDOM % 25 + 25)) #25 - 49
  base=`echo "($median * $base_multiplier) / 1" | bc`

  count=1
  for i in `echo -e "0\\n1\\n2" | sort -R`; do
    ratio=`echo "${base}/${runtime[$i]}" | bc -l`
    testcase=("${testcase[@]}" \
      "lava-test-case $1[00${count}] --result pass --measurement ${runtime[$i]} --units seconds" \
      "lava-test-case $1[00${count}] --result pass --measurement ${ratio} --units ratio"
      )
    if test $((i%2)) -eq 1; then
      testcase_selected=("${testcase_selected[@]}" \
      "lava-test-case $1 --result pass --measurement ${runtime[$i]} --units seconds" \
      "lava-test-case $1 --result pass --measurement ${ratio} --units ratio" \
      )
      selected_count=$((selected_count + 1))
      selected_product_runtime=`echo "${selected_product_runtime} * ${runtime[$i]}" | bc -l`
      selected_product_ratio=`echo "${selected_product_ratio} * ${ratio}" | bc -l`
    fi
    echo "spec.cpu2006.results.${1%%.*}_${1#*.}.base.00${count}.benchmark: $1"
    echo "spec.cpu2006.results.${1%%.*}_${1#*.}.base.00${count}.reference: ${base}"
    echo "spec.cpu2006.results.${1%%.*}_${1#*.}.base.00${count}.reported_time: ${runtime[$i]}"
    echo "spec.cpu2006.results.${1%%.*}_${1#*.}.base.00${count}.ratio: ${ratio}"
    echo "spec.cpu2006.results.${1%%.*}_${1#*.}.base.00${count}.selected: $((i % 2))"
    echo "spec.cpu2006.results.${1%%.*}_${1#*.}.base.00${count}.valid: S"
    count=$((count + 1))
  done
}

declare -A names
names['fp']='410.bwaves 416.gamess 433.milc 434.zeusmp 435.gromacs 436.cactusADM 437.leslie3d 444.namd 447.dealII 450.soplex 453.povray 454.calculix 459.GemsFDTD 465.tonto 470.lbm 481.wrf 482.sphinx3'
names['int']='400.perlbench 401.bzip2 403.gcc 429.mcf 445.gobmk 456.hmmer 458.sjeng 462.libquantum 464.h264ref 471.omnetpp 473.astar 483.xalancbmk'
rm -rf testing
mkdir -p testing/input/result
for bset in fp int; do
  exec {STDOUT}>&1
  exec 1>testing/input/result/C${bset^^}2006.1.ref.rsf
  testcase=('')
  testcase_selected=('')
  selected_count=0
  selected_product_runtime=1
  selected_product_ratio=1
  echo 'spec.cpu2006.size: ref' #TODO: Check when ref run completes
  echo "spec.cpu2006.valid: S" #TODO: Check when ref run completes
  echo "spec.cpu2006.metric: C${bset^^}2006"
  echo "spec.cpu2006.units: SPEC${bset}"
  for name in ${names[${bset}]}; do
    generate_subbenchmark $name
  done
  score=`echo "scale=6; e(l(${selected_product_ratio})/${selected_count})" | bc -l`
  echo "spec.cpu2006.basemean: ${score}"

  for x in "${testcase[@]:1}"; do
    echo "$x" >> testing/golden
  done
  for x in "${testcase_selected[@]:1}"; do
    echo "$x" >> testing/golden
  done
  printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
    "C${bset^^}2006 base runtime geomean" \
    `echo "scale=6; e(l(${selected_product_runtime})/${selected_count})" | bc -l` \
    'geomean of selected runtimes (seconds)' >> testing/golden
  printf 'lava-test-case %s --result pass --measurement %f --units %s\n' \
    "C${bset^^}2006 base score" \
    ${score} \
    "SPEC${bset}" >> testing/golden
  exec 1>&${STDOUT}
done

echo 'lava-test-run-attach RETCODE' >> testing/golden
echo 'lava-test-run-attach stdout' >> testing/golden
echo 'lava-test-run-attach stderr' >> testing/golden
echo 'lava-test-run-attach linarobenchlog' >> testing/golden
echo 'lava-test-run-attach CFP2006.1.ref.rsf' >> testing/golden
echo 'lava-test-run-attach CINT2006.1.ref.rsf' >> testing/golden

TESTING=1 ./CPU200x.sh testing/input > testing/output

if diff testing/{golden,output}; then
  echo "CPU2006 gather script passed self-tests"
  exit 0
else
  echo "CPU2006 gather script FAILED self-tests"
  exit 1
fi