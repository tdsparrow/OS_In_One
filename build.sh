#!/bin/bash
# This script will create a customized Ubuntu installer cdrom 
# initial work is based on https://github.com/cal/vagrant-ubuntu-precise-64
# 
# This script requires a recent Ubuntu system with bsdtar mkisofs cpio sed 
# gnuzip wget utilities to work



# make sure we have dependencies 
for req in bsdtar mkisofs cpio sed gunzip wget curl apt-ftparchive
do
    hash $req 2>/dev/null || { echo >&2 "ERROR: $req not found.  Aborting."; exit 1; }
done

# folder structure
#
#     ├── build                
#     │   └── iso              
#     ├── opt                  
#     │   ├── apt-ftparchive   
#     │   ├── extras           
#     │   └── indices
#     └── puppet               
#
# folder usage:
#
#     build: folder to build iso
#     iso: folder of iso
#     opt: folder for ubuntu package distribution
#     extra: folder for extra deb packages required by OpenStack
#     puppet: puppet folder for OpenStack configuration
#

FOLDER_BASE=`pwd`
FOLDER_BUILD="${FOLDER_BASE}/build"
FOLDER_ISO="${FOLDER_BUILD}/iso"
FOLDER_ISO_CUSTOM="${FOLDER_BUILD}/iso/custom"
FOLDER_ISO_INITRD="${FOLDER_BUILD}/iso/initrd"
BASEDIR=$FOLDER_BASE
BUILD=$BASEDIR/build/iso/custom
APTCONF=$BASEDIR/opt/apt-ftparchive/release.conf
DIST=quantal

source pkg_list


# let's make sure they exist
mkdir -p "${FOLDER_BUILD}"
mkdir -p "${FOLDER_ISO}"

# let's make sure they're empty
echo "Cleaning Custom build directories..."
chmod -R u+w "${FOLDER_ISO_CUSTOM}" >& /dev/null
rm -rf "${FOLDER_ISO_CUSTOM}" >& /dev/null
mkdir -p "${FOLDER_ISO_CUSTOM}" >& /dev/null
chmod -R u+w "${FOLDER_ISO_INITRD}" >& /dev/null
rm -rf "${FOLDER_ISO_INITRD}" >& /dev/null
mkdir -p "${FOLDER_ISO_INITRD}" >& /dev/null

# download Ubuntu installer cdrom
ISO_URL="http://releases.ubuntu.com/12.10/ubuntu-12.10-server-amd64.iso"
ISO_FILENAME="${FOLDER_ISO}/`basename ${ISO_URL}`"
ISO_MD5="4bd3270bde86d7e4e017e3847a4af485"
INITRD_FILENAME="${FOLDER_ISO}/initrd.gz"

# download the installation disk if you haven't already or it is corrupted somehow
function download_iso() {
    echo "Downloading ubuntu-12.10-server-amd64.iso ..."
    if [ ! -e "${ISO_FILENAME}" ] 
    then
        curl --output "${ISO_FILENAME}" -L "${ISO_URL}"
    else
  # make sure download is right...
        ISO_HASH=`md5sum "${ISO_FILENAME}" | awk '{ print $1 }'`
        if [ "${ISO_MD5}" != "${ISO_HASH}" ]; then
            echo "ERROR: MD5 does not match. Got ${ISO_HASH} instead of ${ISO_MD5}. Aborting."
            exit 1
        fi
    fi
}
# patch initrd of installer to replace our preseed.cfg for unattend installation
# for more information google ubunut preseed
function patch_initrd() {
  # backup initrd.gz
    echo "Backing up current init.rd ..."
    _path="${FOLDER_ISO_CUSTOM}/install ${FOLDER_ISO_CUSTOM}/install/initrd.gz ${FOLDER_ISO_CUSTOM}/preseed"
    chmod u+w ${_path}
    mv "${FOLDER_ISO_CUSTOM}/install/initrd.gz" "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org"

  # stick in our new initrd.gz
    echo "Installing new initrd.gz ..."
    cd "${FOLDER_ISO_INITRD}"
    gunzip -c "${FOLDER_ISO_CUSTOM}/install/initrd.gz.org" | cpio -id
    cd "${FOLDER_BASE}"
    cp preseed.cfg "${FOLDER_ISO_INITRD}/preseed.cfg"
    cp preseed-nopart.cfg "${FOLDER_ISO_CUSTOM}/preseed/"
    cp preseed-trial.cfg "${FOLDER_ISO_CUSTOM}/preseed/"
    cd "${FOLDER_ISO_INITRD}"
    find . | cpio --create --format='newc' | gzip  > "${FOLDER_ISO_CUSTOM}/install/initrd.gz"

  # clean up permissions
    echo "Cleaning up Permissions ..."
    chmod u-w ${_path}
}

# replace isolinux configuration for lubantu boot menu
function replace_isolinux() {

    # replace isolinux configuration
    echo "Replacing isolinux config ..."
    cd "${FOLDER_BASE}"
    chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux" "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
    rm "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"
    cp isolinux.cfg "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.cfg"  
    chmod u+w "${FOLDER_ISO_CUSTOM}/isolinux/isolinux.bin"
    
}

# late_command.sh will be executed at the end of Ubuntu installation
# this script will copy puppet modules 
function add_late_command() {

    # add late_command script
    echo "Add late_command script ..."
    chmod u+w "${FOLDER_ISO_CUSTOM}"
    cp "${FOLDER_BASE}/late_command.sh" "${FOLDER_ISO_CUSTOM}"

}

# build iso image containing our patched content
function mkiso() {
    echo "Running mkisofs ..."
    mkisofs -r -V "Custom Ubuntu Install CD" \
        -cache-inodes -quiet \
        -J -l -b isolinux/isolinux.bin \
        -c isolinux/boot.cat -no-emul-boot \
        -boot-load-size 4 -boot-info-table \
        -o "${FOLDER_ISO}/custom.iso" "${FOLDER_ISO_CUSTOM}"

}

# get deb pkgs url list from repo
function generate_deb_uris() {
    _pkg_dist="http://us.archive.ubuntu.com/ubuntu/dists/quantal/main/binary-amd64/Packages.gz \
 http://us.archive.ubuntu.com/ubuntu/dists/quantal/universe/binary-amd64/Packages.gz"
    _temp=`mktemp`
    _repo="http://us.archive.ubuntu.com/ubuntu"

    for dist in $_pkg_dist; do
        curl $dist | zcat | grep -i filename | awk '{print $2}' >> $_temp
    done
    
    : > deb_uris_new
    for pkg in $PKG_LIST; do
        _path=`grep "/${pkg}_[0-9]" $_temp`
        if [ ! -z ${_path} ]; then
            echo "${_repo}/${_path}" >> deb_uris_new
        else
            echo "Missing pkg $pkg" && exit 1
        fi
    done

    if ! sort deb_uris_new | diff deb_uris - ; then
        echo "All above packages changed since last commit!"
    fi
    sort deb_uris_new > deb_uris
    
    rm $_temp
}

# download deb pacakges required by OpenStack 
function fetch_debs() {
    echo "Fetching package for $PKG_LIST"
    
    mkdir -p $BASEDIR/opt/extras
    
    generate_deb_uris

    wget -N -c -i deb_uris -P $BASEDIR/opt/extras
    cp $BASEDIR/opt/extras/*.deb $BUILD/pool/extras    
}

# download extra deb packages and generate repository index for cdrom
function add_extra_packages() {

    chmod -R u+w $BUILD/dists/quantal
    chmod -R u+w $BUILD/pool
    chmod u+w $BUILD/md5sum.txt

    mkdir -p $BUILD/dists/quantal/extras/binary-amd64
    mkdir -p $BUILD/pool/extras

    fetch_debs

    # since we didn't sign our cdrom, no need patch keyring pacakge
    #cp $BASEDIR/opt/build/u/ubuntu-keyring/*deb $BUILD/pool/main/u/ubuntu-keyring/

    echo "Expand absolute path in apt conf"
    find $BASEDIR/opt/apt-ftparchive -name "*.conf" -exec sed -i -e "s#BASEDIR#$BASEDIR#g" {} \;

    pushd $BUILD
    apt-ftparchive -c $APTCONF generate $BASEDIR/opt/apt-ftparchive/apt-ftparchive-deb.conf
    apt-ftparchive -c $APTCONF generate $BASEDIR/opt/apt-ftparchive/apt-ftparchive-udeb.conf
    apt-ftparchive -c $APTCONF generate $BASEDIR/opt/apt-ftparchive/apt-ftparchive-extras.conf
    apt-ftparchive -c $APTCONF release $BUILD/dists/$DIST > $BUILD/dists/$DIST/Release

    rm -f $BUILD/dists/$DIST/Release.gpg
    gpg --default-key "AD1EC320" --output $BUILD/dists/$DIST/Release.gpg -ba $BUILD/dists/$DIST/Release
    find . -type f -print0 | xargs -0 md5sum > md5sum.txt
    popd


    chmod -R u-w $BUILD/dists/quantal
    chmod -R u-w $BUILD/pool
    chmod u-w $BUILD/md5sum.txt
}

# initial Ubuntu base system contain built-in keyring for secure repository
# this base system is extracted from a readonly squashfs, patch it to include
# lubantu keyring

function replace_root_fs() {
    chmod -R u+w $BUILD/install
    cp $BASEDIR/filesystem.squashfs $BUILD/install
    chmod -R u-w $BUILD/install
}

function add_puppet() {
    cp -R $BASEDIR/puppet $BUILD/
}

# main logic
function main() {
    echo "Creating Custom ISO"
    if [ ! -e "${FOLDER_ISO}/custom.iso" ]; then

        download_iso

        echo "Untarring downloaded ISO ..."
        bsdtar -C "${FOLDER_ISO_CUSTOM}" -xf  "${ISO_FILENAME}"

        patch_initrd

        replace_isolinux

        add_late_command

        add_extra_packages

    # since we didn't sign our cdrom, no need to replace key in base system
    #replace_root_fs

        add_puppet

        mkiso
    fi
}

trap 'exit -1' INT

if [ $# -gt 0 ]; then
    _name=$1;shift
    $_name $@
else
    main
fi
