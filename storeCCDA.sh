#!/usr/bin/env bash
outputDir=/home/synthea/output
ccdaDir=$outputDir/ccda/
sdaDir=$outputDir/sdarepo/
filename=$1

if [ ! -d $ccdaDir ]; then
   sudo mkdir -p $ccdaDir
fi

if [ ! -d $sdaDir ]; then
   sudo mkdir -p $sdaDir
fi

ccontrol session STRESS <<- EOS
_system
SYS
zn "HSLIB" zw ##class(Synthea.CCDAtoSDAConverter).ConvertCCDA("$ccdaDir","$sdaDir","$filename") 
EOS

sudo rm -f $ccdaDir/$filename
sudo rm -f $sdaDir/$filename

done
