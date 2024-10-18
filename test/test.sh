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
  echo "Bash srcipt to run ATLAS validation tests"
  echo "Usage:"
  echo "   ./test.sh clean    => clean test folders"
  echo "   ./test.sh run      => run all the validation tests"
  exit 1
}

[ $# == 0 ] && print_usage

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
  echo $CODE >> $FILE
  echo $CODE
  cd $CODE
  for TEST in $(ls -d */); do
    echo $TEST >> $FILE
    cd $TEST
    [ $@ == clean ] && rm -rf *.dat *.txt error* *.out *.data *.tec fromATLAS*
    if [[ $@ == run ]]; then
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
[ $@ == clean ] && rm $FILE
