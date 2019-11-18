#!/bin/bash
# ------------------------------------------------------------------
# [Aaron Kollasch]  jobinfo.sh
#                   Provides information on your SLURM jobs.
#
# Usage:            jobinfo <job id>
#
# Installation:     Source this script in your ~/.bashrc file.
# ------------------------------------------------------------------

jobinfo() {
    # if no argument is given, then print info on all running or recently finished jobs
    if [[ $# -eq 0 ]]; then
        squeue -u "$USER" -t 'all'
        return 0
    fi

    # print job name and time limit before seff output
    echo "Job Name: $(sacct -o jobname,timelimit -j $1 -n -P | head -n 1 | sed -e 's/|/\nTime Limit: /')"

    # seff prints efficiency and other info for the job
    seff "$1"
    echo

    # sacct prints a table of info on completed job steps
    sacct -o jobid,alloccpus,state,reqmem,maxrss,averss,maxvmsize,elapsed -j "$1"

    # sstat prints info on currently running job steps
    # capture stdout and stderr to eliminate duplicate sstat check
    # https://stackoverflow.com/questions/13806626/capture-both-stdout-and-stderr-in-bash
#    eval "$({ serr=$({ sout=$(sstat -o jobid,ntasks,avecpu,avecpufreq,maxrss,averss,maxvmsize,avevmsize -j $1); sret=$?; } 2>&1; declare -p sout sret >&2); declare -p serr; } 2>&1)"
    eval "$({
        SERR=$({
            SOUT=$(sstat -o jobid,ntasks,avecpu,avecpufreq,maxrss,averss,maxvmsize,avevmsize -j "$1")
            SRET=$?
        } 2>&1
        declare -p SOUT SRET >&2)
        declare -p SERR
    } 2>&1)"

    if [[ -z "$SERR" ]]; then
        echo
        echo -e "$SOUT"
    fi

    # sprio prints priority info on jobs that have not yet started
    SOUT=$(sprio -j "$1")
    if [[ ${SOUT} != "Unable to find jobs matching user/id(s) specified" ]]; then
        echo
        echo -e "$SOUT"
    fi
}

# jobinfo supports tab autocomplete to fill job ids
# - if there are currently running jobs, only these will be filled.
# - if there are no currently running jobs, recently completed jobs will also appear.
_comp_jobinfo()
{
    # complete with currently running jobs
    _script_commands="$(squeue -u "$USER" -h -t 'R,CG' -o '%i' | tr '\n' ' ')"

    # if there are no currently running jobs, complete with all recent jobs
    if [[ -z "$_script_commands" ]]; then
        _script_commands="$(squeue -u "$USER" -h -o '%i' -t 'all' -S '-e' | tr '\n' ' ')"
    fi

    # otherwise, complete with nothing
    if [[ -z "$_script_commands" ]]; then
        _script_commands=" "
    fi

    local cur
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "${_script_commands}" -- "${cur}") )

    return 0
}
complete -o nospace -F _comp_jobinfo jobinfo
