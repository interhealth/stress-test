irisKey=$1
irisKeyDefault=/nethome/synthea/iris.key
mgrDir=""
instanceName="STRESS"

for instance in `iris qlist | tr -d ' '`
    do
        Ins=`echo $instance | cut -d '^' -f 1`
        InsDir=`echo $instance | cut -d '^' -f 2`
        if [ $Ins == $instanceName ]; then
          mgrDir=$InsDir
        fi
    done

if [ -z "$irisKey" ]; then
   $irisKey=$irisKeyDefault
fi
sudo cp $irisKey $mgrDir 

iris session STRESS <<- EOS
_system
SYS
zn "%SYS" d ##class(%SYSTEM.License).Upgrade()
EOS
