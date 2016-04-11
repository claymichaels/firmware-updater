#!/bin/bash
# v1.5 - clay michaels 9 Nov 2015
#   Scan for newest PROJECT.conf files in confs folder
#   Added retry loop for invalid input
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
    if ! [ $confirm = "y" ]
    then
        echo "Exiting script!"
        exit 1
    fi
}

confirm_or_exit() {
    if [ $1 -eq 0 ] # completed successfully
    then
        colorize green "Done."
    else
        colorize red "PROBLEM!"
        confirm=null
        counter=1
        while ! [[ "y n" =~ $confirm ]]
        do
            read -e -p "Continue? (y/n)" -i "n" confirm
            if [ "$confirm" = "n" ]
            then
                echo "Exiting script!"
                echo "You may need to fix the CCU "
                echo "  depending on where this cut out."
                exit 1
            elif [ "$confirm" = "y" ]
            then
                echo "Continuing despite error. On your head be it!"
            fi
            ((counter++))
            if [[ $counter -ge 4 ]]
            then
                echo "Exiting script!"
                echo "You may need to fix the CCU "
                echo "  depending on where this cut out."
                exit 1
            fi
        done
    fi
}


echo "Read in target CCU \"$1\""
echo "Expected format is \"amfleet.9649\""
confirm_continue
ccu=$1

echo "Sending FW:/var"
rsync /home/automation/scripts/clayScripts/dev/deployment_files/firmware/4.19.3-1_boot.tar.gz "$ccu":/var > /dev/null 2>&1
confirm_or_exit $?

echo "Sending Scout binary:/var"
rsync /home/automation/scripts/clayScripts/dev/deployment_files/patches/scout $ccu:/conf/extra/usr/local/bin/scout > /dev/null 2>&1
confirm_or_exit $?

echo "UnTARing firmware"
ssh $ccu "tar -zxf /var/4.19.3-1_boot.tar.gz -C /var" > /dev/null 2>&1
confirm_or_exit $?

echo "Removing old FW from /conf/boot"
ssh $ccu "rm /conf/boot/*.tar.gz;rm /conf/boot/r32*;rm /conf/boot/modules.log;" > /dev/null 2>&1
confirm_or_exit $?

echo "Sending SP2:/conf/boot"
rsync /home/automation/scripts/clayScripts/dev/deployment_files/patches/V4.19.3-1SP2.tar.gz "$ccu":/conf/boot > /dev/null 2>&1
confirm_or_exit $?

echo "Copying new FW to /conf/boot"
ssh $ccu "cp -p /var/4.19.3-1/*.tar.gz /conf/boot;cp -p /var/4.19.3-1/r32* /conf/boot;cp -p /var/4.19.3-1/modules.log /conf/boot;" > /dev/null 2>&1
confirm_or_exit $?


echo "Unlinking old FW in /conf/boot" > /dev/null 2>&1
ssh $ccu "unlink /conf/boot/vmlinuz.nomad"
confirm_or_exit $?


echo "Linking new FW in /conf/boot" > /dev/null 2>&1
ssh $ccu "cd /conf/boot;ln -s ./r3200ccu4_universal_4.19.3-1 vmlinuz.nomad"
confirm_or_exit $?


read -e -p "Output ls of /conf/boot? (y/n)" -i "n" confirm
if [ $confirm = "y" ]
then
    echo "/conf/boot looks like:"
    echo `ssh $ccu "ls -l /conf/boot"`
fi


# Scan for PROJECT.conf version
fleet=${ccu%.*}
confs=(`ls /home/automation/scripts/clayScripts/dev/deployment_files/confs/ | grep $fleet | sort -r`)

if [[ -z $confs ]] # empty var (no output from the ls|grep above)
then
    echo "No PROJECT.conf found"
else
    read -e -p "Send $confs? (y/n)" -i "y" confirm
    if [ $confirm = "y" ]
    then
        echo "Sending PROJECT.conf $confs"
        rsync /home/automation/scripts/clayScripts/dev/deployment_files/confs/$confs  $ccu:/conf/PROJECT.conf > /dev/null 2>&1
        confirm_or_exit $?
        ssh $ccu "md5sum /conf/PROJECT.conf"
    elif [ $confirm = "n" ]
    then
        echo "Not sending PROJECT.conf."
    else
        echo "Invalid response. Skipping PROJECT.conf."
    fi
fi


echo "Syncing twice."
ssh $ccu "sync;sync;" > /dev/null 2>&1
confirm_or_exit $?


echo "!!!!!!!!!!!!!!!!"
echo "Ready to reboot?"
echo "!!!!!!!!!!!!!!!!"
users=`ssh $ccu "ipset -L | grep , -c"`
echo "$users users connected."
read -e -p "REBOOT CCU? (y/n)" -i "n" confirm
if [ $confirm = "y" ]
then
    echo `ssh $ccu "reboot;exit;"`
fi
echo "----------"
echo "Finished $ccu"
