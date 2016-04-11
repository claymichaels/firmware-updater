#!/bin/bash

confirm_continue() {
    read -e -p "Is this correct? (y/n)" -i "y" confirm
    if [ $confirm = "n" ]
    then
        exit 1
    fi
}

confirm_output() {
    if [ -z "$1" ]
    then
        echo "Done."
    else
        echo "Uh-Oh! Response:"
        echo "$1"
        read -e -p "Continue? (y/n)" -i "Y" confirm
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
confirm_output $output

echo "Sending SP2:/conf/boot"
output=`rsync /home/automation/scripts/clayScripts/dev/deployment_files/V4.19.3-1SP2.tar.gz "$1":/conf/boot`
confirm_output $output

echo "Sending Scout binary:/var"
output=`rsync /home/automation/scripts/clayScripts/dev/deployment_files/conf-extra-usr-local-bin/scout $1:/conf/extra/usr/local/bin`
confirm_output $output

echo "UnTARing firmware"
output=`ssh $1 "tar -zxf /var/4.19.3-1_boot.tar.gz -C /var"`
confirm_output $output

echo "Removing old FW from /conf/boot"
output=`ssh $1 "rm /conf/boot/*.tar.gz;rm /conf/boot/r32*;rm /conf/boot/modules.log;"`
confirm_output $output

echo "Copying new FW to /conf/boot"
output=`ssh $1 "cp -pv /var/4.19.3-1/*.tar.gz /conf/boot;cp -pv /var/4.19.3-1/r32* /conf/boot;cp -pv /var/4.19.3-1/modules.log /conf/boot;"`
confirm_output $output

# LS HERE

echo "Unlinking old FW in /conf/boot"
output=`ssh $1 "unlink /conf/boot/vmlinuz.nomad"`
confirm_output $output


echo "Linking new FW in /conf/boot"
output=`ssh $1 "cd /conf/boot;ln -s ./r3200ccu4_universal_4.19.3-1 vmlinuz.nomad"`
confirm_output $output


read -e -p "LOAD MIDWEST PROJECT.CONF? (y/n)" confirm
if [ $confirm = "y" ]
then
    echo "Sending PROJECT.conf"
    output=`rsync midwest2.4.6.conf $1:/conf/PROJECT.conf`
    confirm_output $output
    output=`ssh $1 "sync;sync;"`
    confirm_output $output
    ssh $1 "md5sum /conf/PROJECT.conf"
fi

# LS HERE

echo "!!!!!!!!!!!!!!!!"
echo "Ready to reboot?"
echo "!!!!!!!!!!!!!!!!"
read -e -p "REBOOT CCU? (y/n)" confirm
if [ $confirm = "n" ]
then
    exit
elif [ $confirm = "y" ]
then
    output=`ssh $1 "sync;sync;reboot;exit;"`
    echo "$output"
fi
