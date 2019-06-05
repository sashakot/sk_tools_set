#!/bin/bash

# PID, INTERVAL, RSS are integers
declare -i PID INTERVAL RSS
PNAME=
RSS=$((0)) # Current RSS max

if  [[ "$1" =~ ^[0-9]+$ ]];then
	PID=$1
	if ps -p $1 > /dev/null
	then
		echo "$PID is running"
		PID=$1
	fi
fi

if [[ -z $PID ]]; then
	PNAME=$1
fi

INTERVAL=${2:-10}
LOG_DIR=${3:-/tmp}

echo "$PID $PNAME $INTERVAL"

BASE_NAME=$(basename $0)

usage()
{
	echo "$BASE_NAME helps to system administrator to monitor CPU and memory usage"
	echo ""
	echo "Usage: $BASE_NAME <PID|process name> <interval in sec>"
	echo " Examples:"

	exit 2
}

#while :; do
#	case $1 in
#		-h|--help)
#			usage    # Display a usage synopsis.
#			;;
#		-p|--pid)       # Takes an option argument; ensure it has been specified.
#			if [ "$2" ]; then
#				PID=$2
#				shift
#			else
#				echo 'ERROR: "-p | --pid" requires a non-empty option argument.'
#				usage
#			fi
#			;;
#		-v|--verbose)
#			verbose=$((verbose + 1))  # Each -v adds 1 to verbosity.
#			;;
#		--)              # End of all options.
#			shift
#			break
#			;;
#		-?*)
#			printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
#			;;
#		*)               # Default case: No more options, so break out of the loop.
#			break
#	esac
#
#	shift
#done

# Make sure we got all the required arguments
if [[ $INTERVAL == 0 ]]; then
    usage
    exit
fi

if [[ -z $PID ]] && [[ -z $PNAME ]]; then
    usage
    exit
fi

# Redirect stdout to the log file
#exec 1>$LOG_DIR/server_counters_${PID}.csv


# Write the CSV header
echo "timestamp,rssize (private),vsize (virtual),%mem,%cpu,thread#,fd#"

# This function generates a single line of server counters
function print_output_line()
{
    local pid=$1
    local pgroup=$2

    # Put the output of ps in an array of comma separated values
    local ps_data=( $(ps --no-headers -eLo "pgrp,rssize,vsize,%mem,%cpu" | grep "^ *$pgroup " | sed 's/ * /,/g') )
    local rss=( $(ps --no-headers -eLo "rssize" | grep "^ *$pgroup " | sed 's/ * /,/g') )
    local thread_count=${#ps_data[*]}
    local fd_array=( /proc/$pid/fd/* )
    local fd_count=${#fd_array[*]}

    # Sum the CPU usage of all the threads
    local bc_input="0"
    for line in ${ps_data[*]} ; do
        line=( ${line//,/ } )
        bc_input="$bc_input + ${line[4]}"
    done
    local cpu_usage=$(echo "$bc_input" | bc)

    # Write an output line
    line=${ps_data[0]}
    line=( ${line//,/ } )
    echo $(date "+%Y/%m/%d %H:%M:%S"),${line[1]},${line[2]},${line[3]},$cpu_usage,$thread_count,$fd_count
}

# Dump stack if rss growths
function dump_stack()
{
    local pid=$1
    local pgroup=$2

    local rss=( $(ps --no-headers -eLo "pgrp,rssize" | grep "^ *$pgroup " | awk '{print$2}' ) )

    if (( $rss > $RSS )); then
	 RSS=rss
	 local today=`date '+%Y_%m_%d__%H_%M_%S'`;
	 pstack $pid | gzip > $LOG_DIR/$pid.$today.stack.gz
    fi
}

# Print statistics when the process is running
function print_statistics_pid()
{
	local pid=$1

	# Get the PID's process group
	local pgroup=$(ps --no-header --pid=${pid} -o pgrp | xargs echo)

	while [[ -d /proc/$pid ]]; do
		print_output_line $pgroup
		dump_stack $pid $pgroup
		sleep $INTERVAL
	done
}

# Search for process by name and print statistics
function print_statistics_by_pname()
{
	local name=$1

	while :; do
		pid=`pidof $name`
		RSS=$((0))
		if ! [[ -z $pid ]]; then
			print_statistics_pid $pid
		fi
		sleep $INTERVAL
	done
}

if [[ -z $PNAME ]]; then
	print_statistics_pid $PID
else
	print_statistics_by_pname $PNAME
fi

exit 0
