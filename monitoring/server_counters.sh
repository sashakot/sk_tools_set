#!/bin/bash

# Both PID and INTERVAL are intergers
declare -i PID INTERVAL
PNAME=

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

INTERVAL=${2:-1}
LOG_DIR=${3:-.}

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
    local PGROUP=$1

    # Put the output of ps in an array of comma sepereted values
    ps_data=( $(ps --no-headers -eLo "pgrp,rssize,vsize,%mem,%cpu" | grep "^ *$PGROUP " | sed 's/ * /,/g') )
    thread_count=${#ps_data[*]}
    fd_array=( /proc/$PID/fd/* )
    fd_count=${#fd_array[*]}

    # Sum the CPU usage of all the threads
    bc_input="0"
    for line in ${ps_data[*]} ; do
        line=( ${line//,/ } )
        bc_input="$bc_input + ${line[4]}"
    done
    cpu_usage=$(echo "$bc_input" | bc)

    # Write an output line
    line=${ps_data[0]}
    line=( ${line//,/ } )
    echo $(date "+%Y/%m/%d %H:%M:%S"),${line[1]},${line[2]},${line[3]},$cpu_usage,$thread_count,$fd_count
}

# Print statistics when the process is running
function print_statistics_pid()
{
	local pid=$1

	# Get the PID's process group
	PGROUP=$(ps --no-header --pid=${pid} -o pgrp | xargs echo)

	while [[ -d /proc/$pid ]]; do
		print_output_line $PGROUP
		sleep $INTERVAL
	done
}

# Search for process by name and print statistics
function print_statistics_by_pname()
{
	local name=$1

	while :; do
		pid=`pidof $name`
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
