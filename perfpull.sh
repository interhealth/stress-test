#!/usr/bin/env bash
## Overall structure:
## main is at the bottom. Calls one of:
## SyncDirectory and SyncFile functions.
## Call with -h flag, for usage messages.
##################


BaseDir=/home/hspd  ## dir for non-source-controlled content (parent of perforce dir)

defaultDepot=//healthshare/hspd/latest/internal/databases/TestPD
defaultTarget=$BaseDir/perforce/HSPD/hspd/latest/internal/databases/TestPD

# Function Usage: SyncDirectory <DepotDirectory> <TargetDirectory> <ExcludeSubDirectory>
#
# Take the files from <DepotDirectory> and shove them in <TargetDirectory>.
# Doesn't ask questions, or make assumptions. Just dumps files, overwriting anything already there with the same name
# <DepotDirectory> should be a p4 style path, <TargetDirectory> is a local directory. 
# <ExcludeSubDirectory> should be a relative path, that can be appended onto <DepotDirectory>.
SyncDirectory()
{
    DepotDirectory=${1%/} ## strip trailing slash  
    TargetDirectory=${2%/} ## strip trailing slash
    ExcludeSubDirectory=${3%/} ## strip trailing slash
    ClientName=${P4CLIENTNAME}
    ClientSpec=${TargetDirectory%/}/${ClientName}_spec_`date "+%s"`.txt
   
    if [[ -z $quiet ]]; then  
    echo; echo Depot:"   "$DepotDirectory; echo -n ${ExcludeSubDirectory:+Exclude: $DepotDirectory/$ExcludeSubDirectory$'\n'}; echo Target: $TargetDirectory;
   fi
   
    ## Ensure the source Dir exists in Depot
    ## If the depot location does not exist, grep will find a hit on the word 'error'. 
    if [[ `$P4COMMAND -s dirs "$DepotDirectory" | head -1 | grep -c "error:" ` -eq 1 ]]; then
	if [[ $quiet -lt 2 ]]; then 
        echo Folder not found in depot: $DepotDirectory
	fi
        exit 1
    fi
    ## If we are in No-Op mode, this is as far as we want to go!
    if [[ -n $noop ]]; then 
	if [[ $quiet -lt 2 ]]; then 
	echo Folder was found in depot: $DepotDirectory; 
	fi; 
	exit 0 ; 
    fi 
    
    
    ## Ensure target Directory Exists  -- assume permissions OK
    if [ ! -d "${TargetDirectory}" ]
    then 
	mkdir -p "$TargetDirectory"
	if [[ $? -eq 0 ]]
	then	
		if [[ -z $quiet ]]; then 
		echo "Created P4 TargetDirectory $TargetDirectory"
		fi
	else
		if [[ $quiet -lt 3 ]]; then
		echo "Quit due to error creating target directory $TargetDirectory"
		fi
		exit 1
	fi
    fi


    # Generate a one-time use perforce view for the sync
    (   
    echo "Client: ${ClientName}"
    echo "Options:        allwrite clobber nocompress unlocked nomodtime normdir"
    echo "Root: ${TargetDirectory}"
    echo "View:"
    echo "    \"${DepotDirectory}/...\" //${ClientName}/..."
    if [[ -n $ExcludeSubDirectory ]]; then  echo "   \"-${DepotDirectory}/${ExcludeSubDirectory}/...\" \"//${ClientName}/${ExcludeSubDirectory}/...\""; fi

    ) > ${ClientSpec}

	
    ${P4COMMAND} client -i < ${ClientSpec} > /dev/null 2>&1
    
    if [ $? -gt 0 ] 
    then
        echo "`date` : Problem updating client for user $P4USER using ${ClientSpec}:"
        cat ${ClientSpec}
        return 1
    else
        # retain the ClientSpec if double-verbose. Otherwise, clean it up.
        if [[ ${verbose} -lt 2 ]]; then
         rm ${ClientSpec}
        else echo Client Spec Definition:  ${ClientSpec} 
        fi
    fi  

    ${P4COMMAND} sync -f > /dev/null 2>&1
}

# Function Usage: SyncFile <DepotFile> <TargetFile>
#
# Take the files <DepotFile> and copy it to <TargetFile>.
# Doesn't ask questions. If the Target directory does not exist yet, attempts to create it.
# <DepotFile> should be a p4 style path to a single file, <TargetFile> is a fully-qualified local file.
SyncFile()
{
    DepotFile=${1} ## trailing slash on a file
    TargetFile=$(basename "$2") ## no trailing slash on a file
    TargetDirectory=$(dirname "$2")
    ClientName=${P4CLIENTNAME}
    ClientSpec=${TargetDirectory%/}/${ClientName}_spec_`date "+%s"`.txt


    ## special case: the target file is demonstrably a target dir. To continue as-is would error.
    if [[ -d $TargetDirectory/$TargetFile ]]; then
        TargetDirectory=$TargetDirectory/$TargetFile
        TargetFile=$(basename "$1")
    fi


    if [[ -z $quiet ]]; then 
    echo; echo "Depot:   $DepotFile"; echo "Target: $TargetDirectory/$TargetFile";
    fi


    ## Ensure the source File exists in the depot
    ## If the depot location does not exist, grep will find a hit on the word 'error'
    if [[ `$P4COMMAND -s fstat -m 1 "$DepotFile" | head -1 | grep -c "error:" ` -eq 1 ]]; then
	if [[ $quiet -lt 2 ]]; then
        echo File not found in depot: $DepotFile
	fi
        exit 1
    fi
    ## If we are in No-Op mode, this is as far as we want to go!
    if [[ -n $noop ]]; then 
	if [[ $quiet -lt 2 ]]; then
	echo File was found in depot: $DepotFile; 
	fi
	exit 0 ;
    fi 


    ## Ensure target Directory Exists  -- assume permissions OK
    if [ ! -d "${TargetDirectory}" ]
    then
        mkdir -p "$TargetDirectory"
        if [[ $? -eq 0 ]]
        then
		if [[ -z $quiet ]]; then 
                echo "Created P4 TargetDirectory $TargetDirectory"
		fi
        else
		if [[ $quiet -lt 3 ]]; then
                echo "Quit due to error creating target directory $TargetDirectory"
		fi
                exit 1
        fi
    fi


    # Generate a one-time use perforce view for the sync
    (
    echo "Client: ${ClientName}"
    echo "Options:        allwrite clobber nocompress unlocked nomodtime normdir"
    echo "Root:  ${TargetDirectory}"
    echo "View:"
    echo "    \"${DepotFile}\" \"//${ClientName}/$TargetFile\""

    ) > ${ClientSpec}

	
    ${P4COMMAND} client -i < ${ClientSpec} > /dev/null 2>&1

    if [ $? -gt 0 ]
    then
	if [[ $quiet -lt 3 ]]; then
        echo "`date` : Problem updating client for user $P4USER using ${ClientSpec}:"
        cat ${ClientSpec}
	fi
        return 1
    else
        # retain the ClientSpec if double-verbose. Otherwise, clean it up.
        if [[ ${verbose} -lt 2 ]]; then
         rm ${ClientSpec}
        else echo Client Spec Definition:  ${ClientSpec}
        fi
    fi

    ## Do the sync
    ## Common error "open for write: ...: Is a directory" has been avoided.
    ${P4COMMAND} sync -f > /dev/null 2>&1

}



# MAIN
while getopts "d:t:e:fhnqv" opt; do
  case $opt in
    d) depot="$OPTARG";;
    t) target="$OPTARG";;
    e) exclude="$OPTARG";; 
    f) files=1;;
    n) noop=1;;
    q) let quiet=${quiet}+1;;
    v) let verbose=$verbose+1;;
    h|\?) echo "Usage: `basename $0` [-n] [-q]  [-f] [-d DEPOTDIR] [-t TARGETDIR] [-e EXCLUDESUBDIR]";

        echo " Take the files from <DepotDirectory> and shove them in <TargetDirectory>."
        echo " P4User is 'hspdinstaller', client-spec is named 'QDHSPD'."

        echo " OPTIONS: "

        echo " -d DEPOTDIR : DepotDirectory should be a p4 style path" 
        echo "    Default is $defaultDepot"
        echo " -t TARGETDIR : TargetDirectory is a local directory."
        echo "    Default is $defaultTarget"

        echo " -e EXCLUDESUBDIR : Excluded Sub-Directory should be relative to DepotDirectory."
        echo "    Default is not to exclude anything."	

        echo " -f : The values given in -d and -t are FILES, not directories. "
        echo "   (When using -f, the -e option is ignored.)"
        echo "    Special case: if -t names an existing directory, create a file IN the directory, using the same"
        echo "    name as the file had in the depot. If the -t value does not already exist, it must provide the filename."
        echo "    Please note: the Perforce wildcard '*' can be used to match multiple files."
        echo "    When using a wildcard, both source and target should include the asterisk (or target must be an existing dir)."
        echo "    The asterisk in the target file names will be filled in with the substrings matched by the asterisk in the depot names."
        echo "    Any asterisk character must be escaped or quoted, to protect it from expansion by the shell."
        echo "    Example: perfpull.sh -f -t '//depot/foo*' -t '/dir/subdir/bar*.bck'  # will result in foo001.txt -> bar001.txt.bck" 

        echo " -n : No-op mode. Checks if the directory or file exists in the depot, without attempting actual sync."
        echo "    Script returns success if the directory or file does exist, and 1 if it does not exist."
        
        echo " -q : Quiet mode. During normal (non-quiet) operation, the Source and Target info is echoed to the screen"
        echo "    and a message is shown if the Target directory needed to be created."
        echo "    In Quiet mode, by contrast, these messages are suppressed and output is written only in error conditions."
        echo "    Except that the 'exists/does not exist' message (which is specific to No-op mode) is still written out." 
        echo "    In Very Quiet mode (two -q), the message from No-op mode is also suppressed and only the return code "
        echo "    distinguishes whether the file/directory exists in the depot."
        echo "    In Super Quiet mode (three -q), the error-condition messages are also suppressed."

        echo " -v : Verbose "
        echo "     Single -v does nothing at this time. "
        echo "     Double -v retains the Perforce Client Spec definition file for review."


	exit 0
  esac
done


P4CLIENTNAME="QDHSPD"
P4COMMAND="/usr/local/bin/p4 -c ${P4CLIENTNAME}  -u hspdinstaller -P 12345"

if [[ -z $files ]] ; then
        SyncDirectory "${depot:-$defaultDepot}" "${target:-$defaultTarget}" "${exclude}"
else
        SyncFile "${depot:-$defaultDepot}" "${target:-$defaultTarget}"
fi

