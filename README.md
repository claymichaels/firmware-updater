# firmware-updater
A tool to deploy firmware, patches, and configuration files to an entire fleet.

This tool sends the latest firmware and patched to an entire fleet. 
It records updated systems in a log file, and uses that log file to skip updated vehicles on subsequent passes.
If a configuration file is found, that will be sent as well. (Assuming it is approved)
After a successful update, the system is checked for connected users, and the script operator may choose to initiate a reboot at his or her discretion.
