#!/bin/bash

cd ./$1

#for file in *
#do
#  echo $(head -n 1 $file)
#    [ "$(sed -n '/^#--include/p;q' "$file")" ] && printf '%s\n' "$file"
#done

#for filename in [ -f "$i" ]; do
#  echo $(head -n 1 $file)
#done

#find . -type f -exec bash -c '[[ "$( file -bi "$1" )" == */x-shellscript* ]]' bash {} \; -print | grep -v .ex4
find . -type f -exec bash -c 'echo $(head -n 1 ""$1"")' bash {} \; -ls | grep -v .ex4
find . -type f -exec bash -c '[[ $(head -n 1 -c 5 ""$1"") == "//+--" ]] || echo "$1"' bash {} \; -ls | grep -v .ex4
