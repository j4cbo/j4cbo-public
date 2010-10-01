#!/usr/bin/bash

f () {
  if [ "$#" == 0 ]
  then
    echo "Usage: f regex [files]"
  elif [ "$#" == 1 ]
  then
    grep -Ir "$1" *
  else
    grep -Ir $*
  fi
}
    
if [ -f ~/TODO ]
then
  cat ~/TODO
fi
