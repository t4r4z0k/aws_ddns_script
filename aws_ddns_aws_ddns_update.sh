#!/bin/bash
#source config file
WorkingDir=$(dirname $0)
ConfFile="$WorkingDir/config"
. $ConfFile
#set full file paths
LogFile="$WorkingDir/$LogFile"
JsonRawFile="$WorkingDir/$JsonRawFile"
JsonOutFile="$WorkingDir/$JsonOutFile"
#define functions
timestamp() {
  date +%F" "%T # current date and time in format YYYY-MM-DDThh:mm:ss
}
updlog () {
	echo "$1"
	echo "$(timestamp): $1" >> $LogFile
}
#place holders used in the json file: *comment*, *domain*, *newip*
PhComment='*comment*'
PhDomain='*domain*'
PhIp='*newip*'
updlog "$MsgStart"
updlog "user executing the script: $(whoami)"
updlog "checking IP configuration of the \"A\" record of domain $DomainName"
IpExt="$(curl -s https://ipinfo.io/ip)"
updlog "Current external IP: $IpExt"
IpAws="$(aws route53 list-resource-record-sets --hosted-zone-id "$AwsZoneId" --query "ResourceRecordSets[?Name == '"$DomainName".'&&Type == 'A'].ResourceRecords[0].Value" --output text)"
updlog "IP of \"A\" record of $DomainName in AWS Route53: $IpAws"
if  [ $IpExt == $IpAws ]
then
	updlog "IP addresses match: no action required"
	updlog "$MsgEnd"
	exit
fi
JsonTxt=$(cat $JsonRawFile)
#update comment in the JSON
UpdTxt="\""$UpdTxt"\""
JsonTxt="${JsonTxt/"$PhComment"/"$UpdTxt"}"
#update domain name in the JSON
DomainName="\""$DomainName"\""
JsonTxt="${JsonTxt/"$PhDomain"/"$DomainName"}"
#update the IP address in the JSON
IpExt="\""$IpExt"\""
JsonTxt="${JsonTxt/"$PhIp"/"$IpExt"}"
#remove the JSON output file if it exists
if [ -f $JsonOutFile ]
then
	rm $JsonOutFile
fi
echo "$JsonTxt" >> $JsonOutFile #double qouting the variable is needed to preserve line breaks
AwsUpdStat="$(aws route53 change-resource-record-sets --hosted-zone-id "$AwsZoneId" --change-batch file://"$JsonOutFile" --output text)"
updlog "$AwsUpdStat"
rm $JsonOutFile
#to check the status of the change exetcute this with the proper changeId
#aws route53 get-change --id "FullChangeIdHere" --output text
updlog "$MsgEnd"
