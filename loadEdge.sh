edge=$1
if [ -z "$1" ] ;
then
  echo "please specify edge name"
  exit
fi
cwd=$(pwd)
iris session STRESS <<- EOS
_system
SYS
zn "$edge" d \$SYSTEM.OBJ.ImportDir("$cwd/QDHS/","*.xml","cfk",,1) 
EOS
