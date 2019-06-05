#!/bin/bash

# PID, INTERVAL, RSS are integers
declare -i PID INTERVAL RSS
BASE_NAME=$(basename $0)
PNAME=
LOG_DIR=${LOG_DIR:-/tmp}
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

usage()
{
	echo "$BASE_NAME helps to system administrator to monitor CPU and memory usage"
	echo ""
	echo "Usage: $BASE_NAME <PID|process name> <interval in sec>"
	echo " In case of PID, the script dumps statistics while the process is up."
	echo " If case of process name, the script runs endless and dumps statistics even if the application was restarted."
	echo " The script monitors RSS. If it's growing, $BASE_NAME dumps zipped stack in $LOG_DIR folder."
	echo "Examples:"
	echo " $BASE_NAME opensm"
	echo " $BASE_NAME \`pgrep opensm\` 10"
	echo "Configuration:"
	echo " LOG_DIR - Directory for stack dumps"
	echo "Output:"
	echo "  timestamp,rssize (private),vsize (virtual),%mem,%cpu,thread#,fd#"
	echo "  timestamp : Time stamp"
	echo "  rssize (private) : Resident set size (RSS) in KB, is the portion of memory occupied by a process that is held in main memory (RAM)"
	echo "  vsize (virtual) : total VM size in kB. It includes all memory that the process can access including swapped and shared memory"
	echo "  %mem : ratio of the process's resident set size to the physical memory on the machine, expressed as a percentage"
	echo "  %cpu : CPU usage in percentage, including all threads."
	echo "  thread#: Number of running threads"
	echo "  fd#: Number of opened file descriptors"
	echo "Dependency:"
	echo " pstack, gzip"
	echo "Unpack stack file:"
	echo " gunzip -c $LOG_DIR/6996.2019_06_05__18_44_04.stack.gz"

	exit 2
}

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

function has_pstack()
{
	pstack  > /dev/null 2>&1
	return $?
}

# Dump stack if rss growths
function dump_stack()
{
    local pid=$1
    local pgroup=$2

    has_pstack || return

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
		print_output_line $pid $pgroup
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
