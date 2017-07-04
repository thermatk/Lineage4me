# Lineage4me

A script to build LineageOS for Nexus 5X(bullhead) from source. 

## Usage
Just download build-lineage4me.sh, read and adjust for your needs and execute

## Features
- [Signing](https://wiki.lineageos.org/signing_builds.html), to pass SafetyNet
- Vendor blobs from [TheMuppets repo](https://github.com/TheMuppets/proprietary_vendor_lge)
- [FDroidPrivilegedExtension](https://gitlab.com/fdroid/privileged-extension/blob/master/README.md) is built from source
- Patches for microg [signature spoofing](https://raw.githubusercontent.com/microg/android_packages_apps_GmsCore/master/patches/android_frameworks_base-N.patch) and [non-system unifiednlp](https://raw.githubusercontent.com/microg/android_packages_apps_UnifiedNlp/master/patches/android_frameworks_base-N.patch)
- Adds latest signed [microg](https://microg.org/download.html) apks as system apps
- Grant powersaving opt-out to microg via [google.xml](https://github.com/thermatk/Lineage4me/blob/master/google.xml)
- Root achieved by chaining latest [Magisk beta zip](https://forum.xda-developers.com/apps/magisk/beta-magisk-v13-0-0980cb6-t3618589)
- [A patch to make LineageOS Setup Wizard add the microg repo to F-Droid client, so that the microg apps get updates](https://github.com/thermatk/Lineage4me/blob/master/add_microg_repo_setup.patch)
- Removed some RCS(SMS replacement?), DM(Voice mail for US carriers?) and Google Fi related binaries I don't think I'll ever need
- Removed Jelly(browser) and Eleven(music) because there are better apps bundled
- Removed updater apps because there are no OTAs
- Adds some preinstalled apps to data: [F-Droid client](https://f-droid.org/), [VLC Nightly](https://nightlies.videolan.org/), Firefox, Firefox Focus, Amaze File Manager, Termux, Osmand~

## TODO
- Move microg to /data, except for RemoteDroidGuard.
  - Possible problem: how to automatically grant signature spoofing permission to GmsCore and FakeStore. Some special xml?
- Build ElementalX with patches for Kali NetHunter, instead of useless stock kernel
- Include [battery-optimizing governor tweaks](https://github.com/Alcolawl/Interactive-Governor-Tweaks)
  - Put them into magisk late-start folder?
