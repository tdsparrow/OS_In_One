OS_In_One
=========

OpenStack all-in-one cdrom img build scripts.

# Requirement and Usage
This script need execute in an Ubuntu Linux with apt-utils.

     > ./build.sh

It will generate an ISO img build/iso/custom.iso, which include
 . Ubuntu 12.10 Server amd64
 . all OpenStack G version pkgs
 . All puppet modules for OpenStack configuration, patched from official repo with ipv6 support
 . preseed cfg for un-attendable installtion

# How to work
For the commented code, please refer to
[http://tdsparrow.github.io/OS_In_One/build.html](http://tdsparrow.github.io/OS_In_One/build.html)

