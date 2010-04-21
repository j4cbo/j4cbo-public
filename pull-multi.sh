#!/bin/bash
#
# pull-multi.sh
#
# Update multiple repository checkouts in a directory.
#
# This script iterates through all subdirectories of its parameter and
# examines each to see if it looks like a known VCS repository. If it is,
# the appropriate update/pull command is issued. Additionlly, this attempts
# to see if there are any local changes which have not been committed and
# pushed, and prints out a list of repositories for which this is the case.
#
# Copyright (c) 2010, Jacob Potter. Licensed under the WTFPL.
#

# Make sure we've been given a path to operate on
if [ "$1" == "" ]
then
  echo "Usage: $0 repodir"
  exit 1
fi

# Make TARGETDIR an absolute path
TARGETDIR="`pwd`/$1"
unclean=( )

# Are we using a ControlMaster connection?
if [ -e $TARGETDIR/.master ]
then
  # Tremendously hackish way of finding our ssh session
  master=`cat $TARGETDIR/.master`
  TOKEN=$RANDOM$RANDOM$RANDOM
  echo "Opening connection to $master" 
  ssh $master -f -N echo $TOKEN > /dev/null
fi

# Check for remote repository locations
if [ -e $TARGETDIR/.remotes ]
then
  for remote in `cat $TARGETDIR/.remotes`
  do
    machine=${remote%%:*}
    path=${remote#*:}
    if [ "$machine" != "" -a "$path" != "" ]
    then
      echo "Looking for remote repositories in $remote..."
      repos=`ssh $machine ls $path`
      for repo in $repos
      do
        lrepo=${repo%.git}
        if [ ! -d "$TARGETDIR/$lrepo" ]
        then
          echo "MISSING REPOSITORY: $remote/$repo"
        fi
      done
    fi
  done
fi
    

for d in $TARGETDIR/*
do
  # Skip non-directories
  if [ ! -d "$d" ]
  then
    continue
  fi

  cd "$d"
  dp=`basename "$d"`

  if [ -d "$d/.git" ]
  then
    echo "[$dp: git pull]"
    git pull
    git status | grep 'nothing to commit (working directory clean)' \
      > /dev/null
    a=$?
    git status | grep '# Your branch is ahead of ' > /dev/null
    if [ "(" $? -eq 0 ")" -o "(" $a -eq 1 ")" ]
    then
      unclean[${#unclean[*]}]="$d"
    fi
  elif [ -d "$d/.svn" ]
  then
    echo "[$dp: svn update]"
    svn update
    if [ `svn status | wc -l` -ne 0 ]
    then
      unclean[${#unclean[*]}]="$d"
    fi
  elif [ -d "$d/CVS" ]
  then
    echo "[$dp: cvs up]"
    cvs up
    # TODO: how to see if a CVS repo is clean?
  else
    echo "[$dp: UNKNOWN REPOSITORY TYPE]"
  fi

done

# Warn the user about anything unclean
if [ ${#unclean[*]} -ne 0 ]
then
  echo "The following repositories are not clean: "
  for d in "${unclean[@]}"
  do
    dp=`basename "$d"`
    echo "  $dp"
  done
fi

# Find the SSH master connection, if we started one up.
if [ "$TOKEN" != "" ]
then
  sshpid=`ps -C ssh -wwo pid,command | grep $TOKEN | awk '{print $1}'`
  if [ "$sshpid" != "" ]
  then
    kill $sshpid
    if [ $? -ne 0 ]
    then
      echo "Could not kill SSH master - check for stale connections."
    fi
  fi
fi
