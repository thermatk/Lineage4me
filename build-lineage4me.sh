#!/bin/bash

# clear screen
clear

# install build packages
# sudo apt install -y bc bison build-essential curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick \
#	lib32ncurses5-dev lib32readline-dev lib32z1-dev libesd0-dev liblz4-tool libncurses5-dev libsdl1.2-dev libssl-dev \
#	libwxgtk3.0-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev
# for arch(AUR): aosp-devel, lineageos-devel

# install platform tools
if ls platform-tools/adb 1> /dev/null 2>&1; then
	# running second+ time
	echo "Found platform-tools"
else
	wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
	unzip platform-tools-latest-linux.zip
	rm platform-tools-latest-linux.zip

fi
PATH="${PWD}/platform-tools:$PATH"

# prepare structure
mkdir -p android/lineage/
cd android/lineage

# get latest repo
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo

# init repo for LOS 14.1
if ls .repo/manifest.xml 1> /dev/null 2>&1; then
	# running second+ time
	echo "Second+ run, assume manifests in place"
else
	repo init -u https://github.com/LineageOS/android.git -b cm-14.1

	# add remotedroidguard and binaries
	mkdir .repo/local_manifests/
	wget https://raw.githubusercontent.com/thermatk/Lineage4me/master/local_manifest.xml
	mv local_manifest.xml .repo/local_manifests/local_manifest.xml
fi


# official proper step, replaced by themuppets binaries due to errors and need to attach device
# cd device/lge/bullhead/
# ./extract-files.sh
# cd ../../..


# include microg and fdroid prebuilts
# https://microg.org/download.html
rm -rf packages/apps/FOSS
mkdir -p packages/apps/FOSS
cd packages/apps/FOSS
wget https://raw.githubusercontent.com/thermatk/Lineage4me/master/AdditionalAppsAndroid.mk -O Android.mk
wget https://f-droid.org/repo/org.fdroid.fdroid_104050.apk -O FDroid.apk
wget https://microg.org/fdroid/repo/com.google.android.gms-11059462.apk -O GmsCore.apk
wget https://microg.org/fdroid/repo/com.google.android.gsf-8.apk -O GsfProxy.apk
wget https://microg.org/fdroid/repo/com.android.vending-16.apk -O FakeStore.apk
wget https://microg.org/fdroid/repo/org.microg.gms.droidguard-14.apk -O RemoteDroidGuard.apk
cd ../../..

# sync it all
source build/envsetup.sh
make clean
rm -rf out/
repo sync
repo forall -vc "git reset --hard"

# root!
export WITH_SU=true

# configure caching, jack fix
mkdir -p ccache
export CCACHE_DIR=${PWD}/ccache
export USE_CCACHE=1
prebuilts/misc/linux-x86/ccache/ccache -M 50G
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx8G"

# generate keys for signing, if none found
subject='/C=DE/ST=Munich/L=Munich/O=thermatkCustomBuilds/OU=SigningDept/CN=th-custom/emailAddress=thermatk@thermatk.com'
mkdir -p ~/.android-certs
for x in releasekey platform shared media; do
	if ls ~/.android-certs/$x* 1> /dev/null 2>&1; then
		# already there
		echo "Second+ run, certs already generated"
	else
		./development/tools/make_key ~/.android-certs/$x "$subject";
	fi
done

# signature spoofing and unifiednlp patches
cd frameworks/base
wget https://raw.githubusercontent.com/microg/android_packages_apps_GmsCore/master/patches/android_frameworks_base-N.patch
sed -i -e 's/dangerous/signatureOrSystem/g' android_frameworks_base-N.patch
patch -p1 --no-backup-if-mismatch < android_frameworks_base-N.patch
rm android_frameworks_base-N.patch
wget https://raw.githubusercontent.com/microg/android_packages_apps_UnifiedNlp/master/patches/android_frameworks_base-N.patch
patch -p1 --no-backup-if-mismatch < android_frameworks_base-N.patch
rm android_frameworks_base-N.patch
cd ../..

# microg repo setupwizard patch
cd packages/apps/SetupWizard
wget https://raw.githubusercontent.com/thermatk/Lineage4me/master/add_microg_repo_setup.patch
patch -p1 --no-backup-if-mismatch < add_microg_repo_setup.patch
rm add_microg_repo_setup.patch
cd ../../..

# add packages to build
cat <<EOT >> vendor/lge/bullhead/bullhead-vendor.mk
# OTHER PACKAGES
PRODUCT_PACKAGES += \\
   RemoteDroidGuard \\
   GmsCore \\
   GsfProxy \\
   FakeStore \\
   FDroid \\
   FDroidPrivilegedExtension
EOT

# kill some surely useless binaries, like RCS messaging or Fi
sed -i -e '/RCSBootstraputil \\/d' -e '/RcsImsBootstraputil \\/d' -e '/Tycho \\/d' -e '/rcsimssettings \\/d' \
	-e '/rcsservice/d' -e '/GCS \\/d' -e '/HotwordEnrollment \\/d' \
	-e '/DMConfigUpdate \\/d' -e '/DMService \\/d' -e '/SprintDM \\/d' vendor/lge/bullhead/bullhead-vendor.mk
sed -i -e 's/qcrilhook \\/qcrilhook/g' vendor/lge/bullhead/bullhead-vendor.mk
    
# prepare for build
source build/envsetup.sh
breakfast bullhead

# build
mka target-files-package dist

# assemble and sign
croot
./build/tools/releasetools/sign_target_files_apks -o -d ~/.android-certs \
    out/dist/*-target_files-*.zip \
    signed-target_files.zip    
./build/tools/releasetools/ota_from_target_files -k ~/.android-certs/releasekey \
    --block --backup=true \
    signed-target_files.zip \
    signed-ota_update.zip

# get out and copy build
mkdir -p ../../done
DATE=$(date +"%Y.%m.%d_%H-%M")
cp signed-ota_update.zip ../../done/LineageOS-atHOME-$DATE.zip
cd ../..
