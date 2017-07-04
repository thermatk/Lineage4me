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

# repo requires python2, Arch has 3
virtualenv2 venv
source venv/bin/activate

# get latest repo
if ls ~/bin/repo 1> /dev/null 2>&1; then
	export PATH=$PATH:$HOME/bin
else
	mkdir -p ~/bin
	curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
	chmod a+x ~/bin/repo
	export PATH=$PATH:$HOME/bin
fi

# prepare structure
mkdir -p android/lineage/
cd android/lineage

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
wget https://microg.org/fdroid/repo/com.google.android.gms-11059462.apk -O GmsCore.apk
wget https://microg.org/fdroid/repo/com.google.android.gsf-8.apk -O GsfProxy.apk
wget https://microg.org/fdroid/repo/com.android.vending-16.apk -O FakeStore.apk
wget https://microg.org/fdroid/repo/org.microg.gms.droidguard-14.apk -O RemoteDroidGuard.apk
cd ../../..

# sync it all
if ls build/envsetup.sh 1> /dev/null 2>&1; then
	# cleanup
	echo "Second+ run, cleanup"

	source build/envsetup.sh
	make clean
	rm -rf out/
fi
repo sync --force-sync
repo forall -vc "git reset --hard"
source build/envsetup.sh

# root is replaced with Magisk
# export WITH_SU=true

# configure caching, jack fix
mkdir -p ccache
export CCACHE_DIR=${PWD}/ccache
export USE_CCACHE=1
prebuilts/misc/linux-x86/ccache/ccache -M 50G
export ANDROID_JACK_VM_ARGS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4G"

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
   FDroidPrivilegedExtension
EOT

# kill some surely useless binaries, like RCS messaging or Fi
sed -i -e '/RCSBootstraputil \\/d' -e '/RcsImsBootstraputil \\/d' -e '/Tycho \\/d' -e '/rcsimssettings \\/d' \
	-e '/rcsservice/d' -e '/GCS \\/d' -e '/HotwordEnrollment \\/d' \
	-e '/DMConfigUpdate \\/d' -e '/DMService \\/d' -e '/SprintDM \\/d' vendor/lge/bullhead/bullhead-vendor.mk
sed -i -e 's/qcrilhook \\/qcrilhook/g' vendor/lge/bullhead/bullhead-vendor.mk

# opt-out gmscore from doze
cd vendor/lge/bullhead/proprietary
wget https://raw.githubusercontent.com/thermatk/Lineage4me/master/google.xml
cd ../../../..
cat <<EOT >> vendor/lge/bullhead/bullhead-vendor.mk
PRODUCT_COPY_FILES += \
   vendor/lge/bullhead/proprietary/google.xml:system/etc/sysconfig/google.xml
EOT

# prepare for build
source build/envsetup.sh
breakfast bullhead

# build
mka target-files-package dist

# sign
croot
./build/tools/releasetools/sign_target_files_apks -o -d ~/.android-certs \
    out/dist/*-target_files-*.zip \
    signed-target_files.zip

# magisk + additional apps
cat <<EOT > zip-script
ui_print("Installing apps to /data...");
mount("ext4", "EMMC", "/dev/block/platform/soc.0/f9824900.sdhci/by-name/userdata", "/data", "");
package_extract_dir("data", "/data");
set_metadata_recursive("/data/app", "uid", 1000, "gid", 1000, "dmode", 0771, "fmode", 0644, "capabilities", 0x0, "selabel", "u:object_r:apk_data_file:s0");
package_extract_dir("magisk", "/tmp/magisk");
run_program("/sbin/busybox", "unzip", "/tmp/magisk/magisk.zip", "META-INF/com/google/android/*", "-d", "/tmp/magisk");
run_program("/sbin/busybox", "sh", "/tmp/magisk/META-INF/com/google/android/update-binary", "dummy", "1", "/tmp/magisk/magisk.zip");
EOT

# assemble zip + add magisk and apps
./build/tools/releasetools/ota_from_target_files -k ~/.android-certs/releasekey \
    --block --backup=true --extra_script zip-script \
    signed-target_files.zip \
    signed-ota_update.zip
rm zip-script

# add magisk beta(c4377ed) zip to zip
mkdir -p magisk
cd magisk
wget "https://forum.xda-developers.com/attachment.php?attachmentid=4199816&d=1499018891" -O magisk.zip
cd ..
zip -g signed-ota_update.zip magisk/magisk.zip
rm -rf magisk

# Additional apps download
mkdir -p data/app
cd data/app
mkdir -p org.videolan.vlc-1
wget "https://nightlies.videolan.org/build/android-armv8a/VLC-Android-2.1.12-20170704-0058-ARMv8.apk" -O org.videolan.vlc-1/base.apk
mkdir -p org.mozilla.firefox-1
wget "https://download.mozilla.org/?product=fennec-latest&os=android&lang=multi" -O org.mozilla.firefox-1/base.apk
mkdir -p org.mozilla.focus-1
wget "https://github.com/mozilla-mobile/focus-android/releases/download/v1.0/Focus-1.0.apk" -O org.mozilla.focus-1/base.apk
mkdir -p com.amaze.filemanager-1
wget "https://f-droid.org/repo/com.amaze.filemanager_57.apk" -O com.amaze.filemanager-1/base.apk
mkdir -p com.termux-1
wget "https://f-droid.org/repo/com.termux_53.apk" -O com.termux-1/base.apk
mkdir -p net.osmand.plus-1
wget "https://f-droid.org/repo/net.osmand.plus_263.apk" -O net.osmand.plus-1/base.apk
mkdir -p org.fdroid.fdroid-1
wget "https://f-droid.org/repo/org.fdroid.fdroid_104050.apk" -O org.fdroid.fdroid-1/base.apk
cd ../..
# add to zip
zip -r signed-ota_update.zip data/*
rm -rf data
# resign zip
./build/tools/releasetools/sign_zip.py -k ~/.android-certs/releasekey signed-ota_update.zip resigned-ota_update.zip
rm signed-ota_update.zip
mv resigned-ota_update.zip signed-ota_update.zip

# get out and copy build
mkdir -p ../../done
DATE=$(date +"%Y.%m.%d_%H-%M")
cp signed-ota_update.zip ../../done/LineageOS-atHOME-$DATE.zip
cd ../..
