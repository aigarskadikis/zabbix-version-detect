#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/zabbix-version-detect.git && cd zabbix-version-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#take rss feed as an source and get all zabbix stable versions hosted on sourceforge.net
allsfversions=$(wget -qO- http://sourceforge.net/projects/zabbix/rss?path=/ZABBIX%20Latest%20Stable | \
grep "zabbix-" | sed "s/^.*\/zabbix-\|\.tar\.gz.*//g" | sort | uniq | \
sed '$alast line')

printf %s "$allsfversions" | while IFS= read -r version
do {

#check if this version is in database
grep "$version" $db > /dev/null
if [ $? -ne 0 ]
then
echo $version version is new!

url=$(echo http://downloads.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/`echo $version`/zabbix-`echo $version`.tar.gz)

echo $url

#calculate filename
filename=$(echo $url | sed "s/^.*\///g")

#download file
wget $url -O $tmp/$filename -q

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$version">> $db
			
#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$filename" "$url 
$md5
$sha1"
} done
echo
fi

} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
