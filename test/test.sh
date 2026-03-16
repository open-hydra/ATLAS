#!/bin/bash -
#===============================================================================
#
#          FILE: test.sh
#
#         USAGE: ./test.sh
#
#   DESCRIPTION: bash srcipt to run ATLAS validation tests
#===============================================================================
function print_usage {
  echo "Bash script to run ATLAS validation tests"
  echo "Usage:"
  echo "   ./test.sh clean [CATEGORY ...]   => clean test folders"
  echo "   ./test.sh run   [CATEGORY ...]   => run validation tests"
  echo ""
  echo "CATEGORY is one or more of: BCB ICB GPB KAnT (case-sensitive)."
  echo "If no category is given, all categories are run."
  echo ""
  echo "Examples:"
  echo "   ./test.sh run              => run all tests"
  echo "   ./test.sh run BCB ICB      => run only BCB and ICB tests"
  echo "   ./test.sh clean BCB        => clean only BCB test folders"
  exit 1
}

[ $# == 0 ] && print_usage

ACTION=$1
shift

# Remaining arguments are category filters; empty means "all".
CATEGORIES=("$@")

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FILE=$(pwd)/testlog.txt
rm -f $FILE

echo 'ATLAS TEST SESSION' >> $FILE
date >> $FILE
echo >> $FILE

ulimit -s unlimited

for CODE in $(ls -d */); do
  CODE_NAME=${CODE%/}

  # If categories were specified, skip those not listed.
  if [[ ${#CATEGORIES[@]} -gt 0 ]]; then
    match=0
    for cat in "${CATEGORIES[@]}"; do
      [[ "$cat" == "$CODE_NAME" ]] && match=1
    done
    [[ $match -eq 0 ]] && continue
  fi

  echo $CODE >> $FILE
  echo $CODE
  cd $CODE
  for TEST in $(ls -d */); do
    echo $TEST >> $FILE
    cd $TEST
    [[ $ACTION == clean ]] && rm -rf error* fromATLAS* KAnT-out* *.out points.txt couples.txt volumes.txt
    if [[ $ACTION == run ]]; then
      $ATLASDIR/ATLAS.sh ${CODE%?} 1>>$FILE 2>error_file
      size=$(wc -c error_file | awk '{print $1}')
      if [[ $size == "0" ]]; then
        echo -e "${GREEN}success${NC} - $TEST"
      else
        echo -e "${RED}fail${NC}    - $TEST"
      fi
    fi
    cd ../
    echo >> $FILE
  done
  echo >> $FILE
  echo '---------------------' >> $FILE
  echo >> $FILE
  cd ../
done
[[ $ACTION == clean ]] && rm -f $FILE
