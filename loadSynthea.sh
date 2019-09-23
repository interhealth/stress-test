unzip /nethome/synthea/QDHS.zip
cwd=$(pwd)
iris session STRESS <<- EOS
_system
SYS
zn "HSLIB" d \$SYSTEM.OBJ.LoadDir("$cwd/QDHS/","*.xml","cfk") 
EOS

