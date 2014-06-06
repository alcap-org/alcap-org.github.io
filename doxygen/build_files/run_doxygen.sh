#! /bin/bash 
# Script to run doxygen, designed to be called from cron with something like:
# /path/to/script/run_doxygen.sh
# use the -h for usage

########################################################
# control variables
########################################################
# Hard coded
LogFile=run_doxygen.log
DoxyConfigName=Doxyfile

# Calculated
OriginalWD="`pwd`"
ScriptDirectory="`dirname $(readlink -f $0)`"
DateString="`date`"
DoxyConfigFile="$ScriptDirectory/$DoxyConfigName"

########################################################
# Important setup
########################################################
# Stop on an error (non-zero return)

function DirectToLog(){
  exec &> "$ScriptDirectory/$LogFile"
}

function PrintNowIn(){
echo "Now in: '`pwd`'"
}

########################################################
# Options parsing
########################################################
# source shell flags script
. $ScriptDirectory/shflags

# Set up possible options
DEFINE_string PathToSourceCode '' "Path to source code directory" i
DEFINE_string PathToWebRepo '' "Path to alcap-org.github.io repostory" o
DEFINE_string SourceBranch develop "Branch to use for Source repository" b
DEFINE_string SourceProject AlcapDAQ "Project to use for Source.  Should match PathToSourceCode" p
DEFINE_boolean UseLogFile false "Toggle output to log file or stdout" l
DEFINE_boolean ForceGitPush false "Commit and push all html output" F

# Parse the options
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

PathToSourceCode="$FLAGS_PathToSourceCode"
PathToWebRepo="$FLAGS_PathToWebRepo"
SourceBranch="$FLAGS_SourceBranch"
Project="$FLAGS_SourceProject"
ForceGitPush="$FLAGS_ForceGitPush"
PathToOutputHtml="$PathToWebRepo/doxygen/$Project/$SourceBranch"

if [ -z "$PathToSourceCode" ];then
        echo "ERROR: You must define the PathToSourceCode with option -i"
        echo
        flags_help
        exit 1
elif [ -z "$PathToWebRepo" ];then
        echo "ERROR: You must define the PathToOutputHtml with option -o"
        echo
        flags_help
        exit 1
fi

# Check the directories we need exist
if [ ! -d "$PathToSourceCode" ];then
        echo "Error: Unable to find PathToSourceCode: $PathToSourceCode"
        exit 1
fi
if [ ! -d "$PathToWebRepo" ];then
        echo "Error: Unable to find PathToWebRepo: $PathToWebRepo"
        exit 1
elif [ ! -d "$PathToWebRepo/.git" ];then
        echo "Error: $PathToWebRepo is not a git repository"
        exit 1
fi
mkdir -p "$PathToOutputHtml"

########################################################
# Main processing
########################################################
set -e 
#set -x
# If we're not interactive then send everything to the log file
if ! `tty -s `  ;then
	DirectToLog
fi

echo Running $0 on $DateString

# Change into the directory containing this file
cd `dirname $0`

# In AlcapDAQ, pull the latest version of SourceBranch
cd "$PathToSourceCode"
PrintNowIn
git checkout $SourceBranch
git pull

# Run doxygen over AlcapDAQ
( cat "$DoxyConfigFile" ;
cat <<EOF
OUTPUT_DIRECTORY=$PathToOutputHtml
INPUT=$PathToSourceCode
PROJECT_NAME=$Project
HTML_OUTPUT=.
EOF
) | doxygen -

if [ "${ForceGitPush}" -eq 1 ] ;then
    echo
    echo "Finishing...."
    echo "If you want to commit and push the doxygen output you need to set the -F flag."
    exit 0
fi

# Now add, commit and push everything in the updated output html directory
cd "$PathToOutputHtml"
PrintNowIn
git pull
#git config -l
git add -A $PathToOutputHtml
git commit -m "Automatically regenerated doxygen documentation for $DateString"
git push

# Change back to where we were for interactive mode
cd "$OriginalWD"
