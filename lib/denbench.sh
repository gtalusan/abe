

#!/bin/sh

denbench_init()
{
  _denbench_init=true
  DENBENCH_SUITE=denbench
  DENBENCH_BENCH_RUNS="`grep ^BENCH_RUNS= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_VCFLAGS="`grep ^VFLAGS= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_PARALEL="`grep ^PARELLEL= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_PASSWOD_FILE="`grep ^PASSWORD_FILE= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_CCAT="`grep ^CCAT= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_BUILD_LOG="`grep ^BUILD_LOG= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_RUN_LOG="`grep ^RUN_LOG= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"
  DENBENCH_TARBALL="`grep ^TARBALL= ${topdir}/config/denbench.conf \
    | cut -d '=' -f 2`"

  if test "x$DENBENCH_BENCH_RUNS" = x; then
    DENBENCH_BENCH_RUNS=1
  fi
  if test "x$DENBENCH_PARALLEL" = x; then
    DENBENCH_PARALLEL=1
  fi
  if test "x$DENBENCH_BUILD_LOG" = x; then
    DENBENCH_BUILD_LOG=denbench_build_log.txt
  fi
  if test "x$DENBENCH_RUN_LOG" = x; then
    DENBENCH_RUN_LOG=denbench_run_log.txt
  fi
  if test "x$DENBENCH_TARBALL" = x; then
    error "TARBALL not defined in denbench.conf"
    exit
  fi
}

denbench_run ()
{
  echo "denbench run"
  echo "Note: All results are estimates." >> $DENBENCH_RUN_LOG
  for i in $(seq 1 $DENBENCH_BENCH_RUNS); do
    echo -e \\nRun $i:: >> $DENBENCH_RUN_LOG;
    make -C $DENBENCH_SUITE/* -s rerun;
    cat $DENBENCH_SUITE/consumer/*timev2.log >> $DENBENCH_RUN_LOG;
  done
}

denbench_build ()
{
  echo "denbench build"
  echo VCFLAGS=$VCFLAGS >> $DENBENCH_BUILD_LOG 2>&1
  make -C $DENBENCH_SUITE/*
  COMPILER_FLAGS="$(VCFLAGS)" $(TARGET) >> $DENBENCH_BUILD_LOG 2>&1
}

denbench_clean ()
{
  echo "denbench clean"
}


denbench_build_with_pgo ()
{
  echo "denbench build with pgo"
}

denbench_install ()
{
  echo "denbench install"
}

denbench_testsuite ()
{
  echo "denbench testsuite"
}

denbench_extract ()
{
  echo "denbench extract"
  rm -rf $DENBENCH_SUITE
  mkdir -p $DENBENCH_SUITE
  check_pattern "$SRC_PATH/$DENBENCH_TARBALL*.cpt"
  get_becnhmark  "$SRC_PATH/$DENBENCH_TARBALL*.cpt" $DENBENCH_SUITE
  sync
  local FILE=`ls $DENBENCH_SUITE/$DENBENCH_TARBALL*`
  echo $FILE
  echo "$CCAT $FILE | gunzip | tar xjf - -C $DENBENCH_SUITE"
  $CCAT $FILE | tar xJf - -C $DENBENCH_SUITE
  rm $FILE
}


