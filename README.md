# userify-server-tools
Small tools to manage Userify server

Installation Instructions:
https://userify.com/docs/enterprise/installation/


### debug_shim.sh

This is a simple shell script (read it) that gathers non-sensitive information about your system into a log file in case you need to troubleshoot shim problems. You can review the log file and then you have to manually email it to support. (The information doesn't leave your system until you send it.) This can be run on either servers with shims managed by Userify self-hosted (Enterprise, Express) clusters in your datacenter/VPC, or Cloud.

### install_userify_server.sh

This is the shell script that does the work of installation. It's intended to be executed only on a standard Red Hat/CentOS/Ubuntu/Debian/derivative server. If you have customized the installation AMI, you may need testing to ensure it will install and operate properly. (For example, if you have varied the defaults for SE Linux in RHEL, you should test to ensure that your policies still allow Userify to operate.)

### upgrade.sh

You can manually upgrade Userify Servers if needed with this script. Note that this script is almost never needed, since Userify will automatically apply security patches and the shim automatically upgrades from the server itself. Depending on your SLA and for Userify Enterprise, you may need to upgrade on your server or cluster for version upgrades.




*By purchasing, downloading, using, or installing the Userify software, you indicate that you agree to the Terms and Conditions.*
