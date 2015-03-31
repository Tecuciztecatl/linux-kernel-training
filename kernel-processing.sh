#!/bin/bash
#set -o xtrace

LOGFILE=/kernelimages/log

if [ ! -e "$LOGFILE" ]
then
    touch -f $LOGFILE
fi

function log {
     echo "$(date +"%F %T.%N") : $@"
     echo "$(date +"%F %T.%N") : $@" >> $LOGFILE
}

function search_files {
    #log "INFO: # Of $2 files in $1 = "`ls -l $1/** | grep -i $2 | wc -l`
    echo "`ls -lR $1/* | grep -i $2 | wc -l`"
}

function search_string {
    declare -i count=0
    for f in `find $1/* -type f`; do
        count=$count+`grep -io "$2" < "$f" | wc -w`
    done
    echo "$count"
}

# Still needs work
function search_contributor {
#grep -Eo "[A-Za-z0-9\.\_\-]+@intel.com"
    for f in `find $1/* -type f`; do
        if grep -qio "$2" < "$f"
            echo "$f | $2"
        fi
    done
}

while getopts ":s:v:t:h" opt; do
case $opt in
    s)
      K_SOURCE=`echo $OPTARG | tr '[:upper:]' '[:lower:]'`
      #echo "$K_SOURCE"
      if [[ "$K_SOURCE" == "i" || "$K_SOURCE" == "internet" ]]
      then
          K_SOURCE="i"
      elif [[ "$K_SOURCE" == "l" || "$K_SOURCE" == "local" ]]
      then
          K_SOURCE="l"
      else
          echo "ERROR: -s $K_SOURCE is not a valid parameter, please use [internet|local]"
          exit 1
      fi
      ;;
    v)
      K_VERSION=$OPTARG
      REGEX="^[0-9]\.[0-9]{1,2}\.[0-9]{1,3}$"
      if ! [[ "$K_VERSION" =~ $REGEX  ]]
      then
	echo "ERROR: $K_VERSION : Erroneous version input, please use the format <x.xx.xxx>."
      fi
      ;;
    t)
      F_TYPE=`echo $OPTARG | tr '[:upper:]' '[:lower:]'`
      if [[ "$F_TYPE" != "xz" && "$F_TYPE" != "gz" ]]
      then
          echo "ERROR: -t $F_TYPE is not valid, please use [xz|gz]."
          exit 1
      fi
      ;;
    h)
      printf "\tHelp for kernel-processing.sh\n"
      echo ""
      printf "\tkernel-processing.sh is a script that will . . . .\n"
      echo ""
      printf "\tbash kernel-processing.sh [-s internet|local] [-v kernel_version] [-t file_type]\n"
      printf "\tbash kernel-processing.sh [internet|local] [kernel_version] [xz|gz]\n"
      echo ""
      printf "\t-s\tChoose between internet and local, location from which you will pull the kernel.\n"
      printf "\t-v\tThis is the version of the kernel that will be used <x.xx.xxx>.\n"
      exit 0
      ;;
    \?)
      echo "ERROR: Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "ERROR: Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

#CONFIGURATION
K_DIRECTORY="/kernelimages"
K_URL="https://www.kernel.org/pub/linux/kernel/v3.x"

K_NAME="linux-$K_VERSION"".tar.$F_TYPE"

[ ! -d $K_DIRECTORY ] && mkdir -p $K_DIRECTORY || :
[ ! -d $K_DIRECTORY/pre ] && mkdir -p $K_DIRECTORY/pre || :
[ ! -d $K_DIRECTORY/post ] && mkdir -p $K_DIRECTORY/post || :
[ ! -e $K_DIRECTORY/stats.pre ] && touch $K_DIRECTORY/stats.pre || :
[ ! -e $K_DIRECTORY/stats.post ] && touch $K_DIRECTORY/stats.post || :

if [ "$K_SOURCE" == "i" ]
then
    if [[ ! -e $K_DIRECTORY/$K_NAME ]]
    then
        # First check that the file exists
        RESULT=`curl -s $K_URL/$K_NAME --head`
        if echo "$RESULT" | grep -q -i "OK"
        then
            log "INFO: Downaloding the kernel file $K_URL/$K_NAME ."
            wget --tries=30 -q -c $K_URL/$K_NAME -P $K_DIRECTORY/
        else
            log "ERROR: URL $K_URL/$K_NAME does not exist."
        fi
    else
        log "INFO: kernel file $K_DIRECTORY/$K_NAME already exists."
    fi
fi

if [[ ! -e $K_DIRECTORY/$K_NAME ]]
then
    log "ERROR: Kernel $K_DIRECTORY/$K_NAME does not exist, please use the opction to download it from the internet."
    exit 1
else
    # Validate what to do when the directory is not empty.
    #tar xvf $K_DIRECTORY/$K_NAME -C $K_DIRECTORY/pre
    log "INFO: Extracted the kernel $K_NAME to dir $K_DIRECTORY/pre."
fi

# SAVE the stadistics inside the file stats.pre
# Gathering stats
SUMFILES=0
#    # of READMEs
NFILES=$(search_files "$K_DIRECTORY/pre" "README")
log "INFO: # Of README files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of Kconfig
NFILES=$(search_files "$K_DIRECTORY/pre" "Kconfig")
log "INFO: # Of Kconfig files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of Kbuild
NFILES=$(search_files "$K_DIRECTORY/pre" "Kbuild")
log "INFO: # Of Kbuild files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of Makefiles
NFILES=$(search_files "$K_DIRECTORY/pre" "Make")
log "INFO: # Of MakeFiles files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of .c files
NFILES=$(search_files "$K_DIRECTORY/pre" "\\.o$")
log "INFO: # Of .o files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of .h files
NFILES=$(search_files "$K_DIRECTORY/pre" "\\.h$")
log "INFO: # Of .h files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of .pl files
NFILES=$(search_files "$K_DIRECTORY/pre" "\\.pl$")
log "INFO: # Of .pl files in $K_DIRECTORY/pre = $NFILES"
SUMFILES=$((SUMFILES+NFILES))
#    # of others files
TFILES=`find $K_DIRECTORY/pre -type f | wc -l`
log "INFO: # of other files $((TFILES-SUMFILES))"
#    Total number of files
log "INFO: Total number of files: $TFILES"
#    # of ocurrences for Linus
log "INFO: # of ocurrences of Linus in files = "`search_string $K_DIRECTORY/pre "Linus"`
#    # of architectures/directories found under arch/
log "INFO: # of architechture directories listed under arch/ = "`ls -l $K_DIRECTORY/pre/*/arch | grep ^d | wc -l`
#log "INFO: # of architechture directories listed under arch/ = "`find $K_DIRECTORY/pre/*/arch -maxdepth 1 -type d | wc -l`
#    # of ocurrences for kernel_start
log "INFO: # of ocurrences of kernel_start in files = "`search_string $K_DIRECTORY/pre "kernel_start"`
#    # of ocurrences for __init
log "INFO: # of ocurrences of __init in files = "`search_string $K_DIRECTORY/pre "_init"`
#    # of files in its filename containing the word gpio
log "INFO: # of ocurrences of gpio in filenames = "`search_files $K_DIRECTORY/pre "gpio"`
#    # of ocurrences for #include <linux/module.h>
log "INFO: # of ocurrences of #include <linux/module.h> in files = "`search_string $K_DIRECTORY/pre '\#include <linux/module.h>'`


#Some Tasks To Do

#    Sort in alphabetical order all #include <linux/*> under drivers/i2c/ Make sure you identify all files you have modified, you will need their identity in the post processing phase

#    Let's populate our file called intel.contributors under our top level working directory directory, search for all Intel contributors matching @intel.com and identify the file where their name was located, one line per contributor and cannot repeat contributor e.g.

#Path/to/file.c | Sara Sharp
#Path/to/file.c | Darren Hart
