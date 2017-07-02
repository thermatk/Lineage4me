# Lineage4me

A script to build LineageOS for Nexus 5X(bullhead) from source. 

## Usage
Just download build-lineage4me.sh, read and adjust for your needs and execute

## Features
- [Signing](https://wiki.lineageos.org/signing_builds.html), to pass SafetyNet
- Vendor blobs from [TheMuppets repo](https://github.com/TheMuppets/proprietary_vendor_lge)
- [FDroidPrivilegedExtension](https://gitlab.com/fdroid/privileged-extension/blob/master/README.md) is built from source
- Patches for microg [signature spoofing](https://raw.githubusercontent.com/microg/android_packages_apps_GmsCore/master/patches/android_frameworks_base-N.patch) and [non-system unifiednlp](https://raw.githubusercontent.com/microg/android_packages_apps_UnifiedNlp/master/patches/android_frameworks_base-N.patch)
- Adds latest signed [microg](https://microg.org/download.html) and [F-Droid client](https://f-droid.org/) apks as system apps
- Rooted by chaining latest [Magisk beta zip](https://forum.xda-developers.com/apps/magisk/beta-magisk-v13-0-0980cb6-t3618589)
- [A patch to make LineageOS Setup Wizard add the microg repo to F-Droid client, so that the microg apps might get updates](https://github.com/thermatk/Lineage4me/blob/master/add_microg_repo_setup.patch)
- Removed some RCS(SMS replacement?), DM(Voice mail for US carriers?) and Google Fi related binaries I don't think I'll ever need

## TODO
- Move microg and f-droid to /data, except for RemoteDroidGuard.
  - Probably with a preinstall script or a zip update-script?
  - Possible problem: how to automatically grant signature spoofing permission to GmsCore and FakeStore.
- Build ElementalX with patches for Kali NetHunter which I build separately anyway, instead of useless stock kernel
- Include [battery-optimizing governor tweaks](https://github.com/Alcolawl/Interactive-Governor-Tweaks)
- Include some more apps from F-Droid in /data for a better initial experience: Barcode Scanner. Amaze File Manager, Firefox(Fennec), VLC
