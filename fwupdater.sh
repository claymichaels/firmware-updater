#!/bin/bash
# v1.2 - clay michaels 28 Oct 2015
#   added case for PROJECT.conf versions

confirm_continue() {
    read -e -p "Is this correct? (y/n)" -i "y" confirm
    if [ $confirm = "n" ]
    then
        exit 1
    fi
}

confirm_or_exit() {
    if [ -z "$1" ]
    then
        echo "Done."
    else
        echo "Uh-Oh! Response:"
        echo "$1"
        read -e -p "Continue? (y/n)" -i "y" confirm
        if [ $confirm = "n" ]
        then
            exit 1
        fi
    fi
}


echo "Read in target CCU \"$1\"."
echo "Expected format is \"amfleet.9649\""
confirm_continue

echo "Sending FW:/var"
output=`rsync /home/automation/scripts/clayScripts/dev/deployment_files/4.19.3-1_boot.tar.gz "$1":/var`
confirm_or_exit $output

echo "Sending SP2:/conf/boot"
output=`rsync /home/automation/scripts/clayScripts/dev/deployment_files/V4.19.3-1SP2.tar.gz "$1":/conf/boot`
confirm_or_exit $output

echo "Sending Scout binary:/var"
output=`rsync /home/automation/scripts/clayScripts/dev/deployment_files/conf-extra-usr-local-bin/scout $1:/conf/extra/usr/local/bin`
confirm_or_exit $output

echo "UnTARing firmware"
output=`ssh $1 "tar -zxf /var/4.19.3-1_boot.tar.gz -C /var"`
confirm_or_exit $output

echo "Removing old FW from /conf/boot"
output=`ssh $1 "rm /conf/boot/*.tar.gz;rm /conf/boot/r32*;rm /conf/boot/modules.log;"`
confirm_or_exit $output

echo "Copying new FW to /conf/boot"
output=`ssh $1 "cp -p /var/4.19.3-1/*.tar.gz /conf/boot;cp -p /var/4.19.3-1/r32* /conf/boot;cp -p /var/4.19.3-1/modules.log /conf/boot;"`
confirm_or_exit $output


echo "Unlinking old FW in /conf/boot"
output=`ssh $1 "unlink /conf/boot/vmlinuz.nomad"`
confirm_or_exit $output


echo "Linking new FW in /conf/boot"
output=`ssh $1 "cd /conf/boot;ln -s ./r3200ccu4_universal_4.19.3-1 vmlinuz.nomad"`
confirm_or_exit $output


read -e -p "Output ls of /conf/boot? (y/n)" -i "n" confirm
if [ $confirm = "y" ]
then
    echo "/conf/boot looks like:"
    echo `ssh $1 "ls -l /conf/boot"`
fi


case $1 in
    amfleet*)
        conf=amfleet3.0.6
        ;;
    midwest.*)
        conf=midwest2.4.6.conf
        ;;
    acela.*)
        conf=acela4.0.1
        ;;
    nocal.*)
        conf=nocal2.0.4
        ;;
    socal.*)
        conf=socal2.0.4
        ;;
    *)
        conf=none
        ;;
esac

if [ $conf = "none" ]
then
    echo "No PROJECT.conf available."
else
    read -e -p "Load PROJECT.conf \"$conf\"? (y/n)" confirm
    if [ $confirm = "y" ]
    then
        echo "Sending PROJECT.conf"
        output=`rsync $conf  $1:/conf/PROJECT.conf`
        confirm_or_exit $output
        ssh $1 "md5sum /conf/PROJECT.conf"
    fi
fi


echo "Syncing twice."
output=`ssh $1 "sync;sync;"`
confirm_or_exit $output


echo "!!!!!!!!!!!!!!!!"
echo "Ready to reboot?"
echo "!!!!!!!!!!!!!!!!"
read -e -p "REBOOT CCU? (y/n)" confirm
if [ $confirm = "n" ]
then
    exit
elif [ $confirm = "y" ]
then
    echo `ssh $1 "reboot;exit;"`
fi
