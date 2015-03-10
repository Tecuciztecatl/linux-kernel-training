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
    tar xvf $K_DIRECTORY/$K_NAME -C $K_DIRECTORY/pre
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
echo "Total number of files: $TFILES"
#    # of ocurrences for Linus
#    # of architectures/directories found under arch/
#    # of ocurrences for kernel_start
#    # of ocurrences for __init
#    # of files in its filename containing the word gpio
#    # of ocurrences for #include <linux/module.h>

