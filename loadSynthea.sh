unzip /nethome/synthea/QDHS.zip
cwd=$(pwd)
iris session STRESS <<- EOS
_system
SYS
zn "HSLIB" d \$SYSTEM.OBJ.ImportDir("$cwd/QDHS/","*.xml","cfk") 
EOS

