# server_counters.sh  Simple script for memory and CPU usage monitoring 

The script creates monitors CPU and memory usage for a process and reports result in CSV format

## Usage

```
./server_counters.sh <pid> <time interval in sec>
```

## Examples

``` bash
$ ./server_counters.sh `pgrep opensm` 10
timestamp,rssize (private),vsize (virtual),%mem,%cpu,thread#,fd#
2019/06/05 04:13:40,5572,1097004,0.0,0,35,1
2019/06/05 04:13:50,5572,1097004,0.0,0,35,1
```

## Description

| Column name    | Description                                                            |
|----------------|------------------------------------------------------------------------|
|timestamp       | Local date time                                                        |
|rssize (private)| Resident set size (RSS) in KB, is the portion of memory occupied by a process that is held in main memory (RAM)  |
|vsize (virtual) | total VM size in kB. It includes all memory that the process can access including swapped and shared memory      |
|%mem            | ratio of the process's resident set size  to the physical memory on the machine, expressed as a percentage       |     
|%cpu            | CPU usage in percentage, including all threads.                                                                  |
|thread#         | Number of running threads                                                                                        |
|fd#             | Number of opened file descriptors                                                                                |
