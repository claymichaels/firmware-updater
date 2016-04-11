#!/bin/bash
# v1.4 - clay michaels 6 Nov 2015
#   Trying to add exit code checking to break
# v1.3 - clay michaels 28 Oct 2015
#   Added ipset output before reboot prompt
#   Changed midwest P.c filename
# v1.2 - clay michaels 28 Oct 2015
#   added case for PROJECT.conf versions

colorize() {
    case $1 in
        green)
            echo -e "\e[92m$2\e[0m"
            ;;
        red)
            echo -e "\e[91m$2\e[0m"
            ;;
        blue)
            echo -e "\e[34m$2\e[0m"
            ;;
        yellow)
            echo -e "\e[93m$2\e[0m"
            ;;
    esac
}

confirm_continue() {
    read -e -p "Is this correct? (y/n)" -i "y" confirm
    if [ $confirm = "n" ]
    then
        exit 1
    fi
}

confirm_or_exit() {
    if [ $1 -eq 0 ] # completed successfully
    then
        colorize green "Done."
    else
        colorize red "PROBLEM!"
        read -e -p "Continue? (y/n)" -i "n" confirm
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
rsync /home/automation/scripts/clayScripts/dev/deployment_files/4.19.3-1_boot.tar.gz "$1":/var > /dev/null 2>&1
confirm_or_exit $?

echo "Sending Scout binary:/var"
rsync /home/automation/scripts/clayScripts/dev/deployment_files/conf-extra-usr-local-bin/scout $1:/conf/extra/usr/local/bin > /dev/null 2>&1
confirm_or_exit $?

echo "UnTARing firmware"
ssh $1 "tar -zxf /var/4.19.3-1_boot.tar.gz -C /var" > /dev/null 2>&1
confirm_or_exit $?

echo "Removing old FW from /conf/boot"
ssh $1 "rm /conf/boot/*.tar.gz;rm /conf/boot/r32*;rm /conf/boot/modules.log;" > /dev/null 2>&1
confirm_or_exit $?

echo "Sending SP2:/conf/boot"
rsync /home/automation/scripts/clayScripts/dev/deployment_files/V4.19.3-1SP2.tar.gz "$1":/conf/boot > /dev/null 2>&1
confirm_or_exit $?

echo "Copying new FW to /conf/boot"
ssh $1 "cp -p /var/4.19.3-1/*.tar.gz /conf/boot;cp -p /var/4.19.3-1/r32* /conf/boot;cp -p /var/4.19.3-1/modules.log /conf/boot;" > /dev/null 2>&1
confirm_or_exit $?


echo "Unlinking old FW in /conf/boot" > /dev/null 2>&1
ssh $1 "unlink /conf/boot/vmlinuz.nomad"
confirm_or_exit $?


echo "Linking new FW in /conf/boot" > /dev/null 2>&1
ssh $1 "cd /conf/boot;ln -s ./r3200ccu4_universal_4.19.3-1 vmlinuz.nomad"
confirm_or_exit $?


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
        conf=midwest2.4.6
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
    washdot.*)
        conf=cascadesWA2.0.9
        ;;
    odot.*)
        conf=cascadesOR2.0.1
        ;;
    *)
        conf=none
        ;;
esac

if [ $conf = "none" ]
then
    echo "No PROJECT.conf available."
else
    read -e -p "Load PROJECT.conf \"$conf\"? (y/n)" -i "y" confirm
    if [ $confirm = "y" ]
    then
        echo "Sending PROJECT.conf"
        rsync $conf  $1:/conf/PROJECT.conf > /dev/null 2>&1
        confirm_or_exit $?
        ssh $1 "md5sum /conf/PROJECT.conf"
    fi
fi


echo "Syncing twice."
ssh $1 "sync;sync;" > /dev/null 2>&1
confirm_or_exit $?


echo "!!!!!!!!!!!!!!!!"
echo "Ready to reboot?"
echo "!!!!!!!!!!!!!!!!"
users=`ssh $1 "ipset -L | grep , -c"`
echo "$users users connected."
read -e -p "REBOOT CCU? (y/n)" confirm
if [ $confirm = "n" ]
then
    echo "----------"
    echo "Finished $1"
    exit
elif [ $confirm = "y" ]
then
    echo `ssh $1 "reboot;exit;"`
    echo "----------"
    echo "Finished $1"
fi
