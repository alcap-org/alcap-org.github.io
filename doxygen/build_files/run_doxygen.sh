#! /bin/bash 
# Script to run doxygen, designed to be called from cron with something like:
# /path/to/script/run_doxygen.sh
# use the -h for usage

########################################################
# control variables
########################################################
# Hard coded
LogFile=run_doxygen
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
  exec &> "$ScriptDirectory/$LogFile_$Project.log"
}

function PrintNowIn(){
echo "Now in: '`pwd`'"
}

function CommitMessage(){
echo "Automatically regenerated doxygen documentation for branch '$SourceBranch' of '$Project' on $DateString"
}

function OptionsError(){
echo -e $@
echo
flags_help
exit 1
}

########################################################
# Options parsing
########################################################
# source shell flags script
. $ScriptDirectory/shflags

# Set up possible options
DEFINE_string PathToSourceCode '' "Path to source code directory" i
DEFINE_string PathToWebRepo '' "Path to alcap-org.github.io repostory" o
DEFINE_string SourceBranch '' "Branch to use for Source repository" b
DEFINE_string SourceProject '' "Project to use for Source.  Should match PathToSourceCode" p
DEFINE_string SourceDirectories "" "A space separated list of directories to look for source code.  Will be appended to PathToSourceCode" d
DEFINE_boolean UseLogFile false "Toggle output to log file or stdout" l
DEFINE_boolean ForceGitPush false "Commit and push all html output" F

# Parse the options
FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

PathToSourceCode="${FLAGS_PathToSourceCode}"
SourceDirectories=( ${FLAGS_SourceDirectories[@]} ) 
PathToWebRepo="$FLAGS_PathToWebRepo"
SourceBranch="$FLAGS_SourceBranch"
Project="$FLAGS_SourceProject"
ForceGitPush="$FLAGS_ForceGitPush"
PathToOutputHtml="$PathToWebRepo/doxygen/$Project/$SourceBranch"
InputDirectories=( ${SourceDirectories[@]/#/${PathToSourceCode}} )

echo PathToSourceCode=${PathToSourceCode[@]}
echo SourceDirectories=${SourceDirectories[@]}
echo PathToWebRepo=${PathToWebRepo[@]}
echo SourceBranch=${SourceBranch[@]}
echo Project=${Project[@]}
echo ForceGitPush=${ForceGitPush[@]}
echo PathToOutputHtml=${PathToOutputHtml[@]}
echo InputDirectories=${InputDirectories[@]}

if [ -z "$PathToSourceCode" ];then
        OptionsError "ERROR: You must define the PathToSourceCode with option -i"
elif [ -z "$PathToWebRepo" ];then
        OptionsError "ERROR: You must define the PathToOutputHtml with option -o"
elif [ -z "$Project" ];then
        OptionsError "ERROR: You must define the project to build with option -p"
elif [[ "$PathToSourceCode" != *$Project* ]];then
        OptionsError " ERROR: This script is very cautious.  
        The project name, '$Project' doesn't appear in the PathToSourceCode '$PathToSourceCode'"
        exit 1
elif [ -z "$SourceBranch" ];then
        OptionsError "ERROR: You must define the branch of $Project with option -b"
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

# Change into the directory where the html will go
cd "$PathToOutputHtml"
PrintNowIn
git pull

# In AlcapDAQ, pull the latest version of SourceBranch
cd "$PathToSourceCode"
PrintNowIn
git checkout $SourceBranch
git pull

# Run doxygen over AlcapDAQ
( cat "$DoxyConfigFile" ;
cat <<EOF
OUTPUT_DIRECTORY=$PathToOutputHtml
INPUT=${InputDirectories[@]}
PROJECT_NAME=$Project
HTML_OUTPUT=.
EOF
) | doxygen -

if [ "${ForceGitPush}" -eq 1 ] ;then
    echo
    echo "Finishing...."
    echo "If you want to commit and push the doxygen output you need to set the -F flag."
    echo
    echo "Commit message would be:"
    echo "`CommitMessage`"
    exit 0
fi

# Now add, commit and push everything in the updated output html directory
cd "$PathToOutputHtml"
PrintNowIn
git add -A $PathToOutputHtml
git commit -m "`CommitMessage`"
git push

# Change back to where we were for interactive mode
cd "$OriginalWD"
