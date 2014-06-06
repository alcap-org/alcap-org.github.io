#! /bin/bash 
# Script to run doxygen, designed to be called from cron with something like:
# /path/to/script/run_doxygen.sh

########################################################
# control variables
########################################################
# Hard coded
ConfigFile=Config.sh
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
set -e -x

# If we're not interactive then send everything to the log file
if ! `tty -s ` || [ -n "$1" ] ;then
  exec &> "$ScriptDirectory/$LogFile"
fi


function PrintNowIn(){
echo "Now in: '`pwd`'"
}

########################################################
# Main processing
########################################################
echo Running $0 on $DateString

# Change into the directory containing this file
cd `dirname $0`
PrintNowIn

# Get all local variable definitions
[ ! -f "$ConfigFile" ] && \
echo "Unable to find config file '$ConfigFile' in `pwd`" && exit 1
source "$ConfigFile"

# Check we have all the necessary variables
NeededVariables=( $PathToSourceCode $PathToOutputHtml )
if [ ${#NeededVariables[@]} -ne 2 ];then
        echo "I'm missing important variables"
        exit 1
fi

# Set the GIT_DIR
#export GIT_DIR="`dirname $PathToOutputHtml/`"

# In AlcapDAQ, pull the latest version of develop
cd "$PathToSourceCode"
PrintNowIn

# Run doxygen over AlcapDAQ
( cat "$DoxyConfigFile" ;
echo "OUTPUT_DIRECTORY=$PathToOutputHtml"
echo "INPUT=$PathToSourceCode"
) | doxygen -

# Now add, commit and push everything in the updated output html directory
cd "$PathToOutputHtml"
git pull
PrintNowIn
#git config -l
git add -n -A .
git commit -m "Automatically regenerated doxygen documentation for $DateString"
echo git push

# Change back to where we were for interactive mode
cd "$OriginalWD"
