#!/bin/bash

set -o errexit -o nounset -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"

DELETE_TAG=

build_number=
if [[ $# -eq 1 ]]; then
    build_number=$1
elif [[ $# -ne 0 ]]; then
    user_error "expected 0 or 1 arguments"
fi

aosp_forks=(
    device_common
    device_generic_goldfish
    device_google_barbet
    device_google_barbet-sepolicy
    device_google_bluejay
    device_google_bramble
    device_google_coral
    device_google_coral-sepolicy
    device_google_gs-common
    device_google_gs101
    device_google_gs101-sepolicy
    device_google_gs201
    device_google_gs201-sepolicy
    device_google_pantah
    device_google_raviole
    device_google_redbull
    device_google_redbull-sepolicy
    device_google_redfin
    device_google_sunfish
    device_google_sunfish-sepolicy
    platform_art
    platform_bionic
    platform_bootable_recovery
    platform_build
    platform_build_soong
    platform_development
    platform_external_android-nn-driver
    platform_external_armnn
    platform_external_conscrypt
    platform_external_crosvm
    platform_frameworks_av
    platform_frameworks_base
    platform_frameworks_ex
    platform_frameworks_libs_modules-utils
    platform_frameworks_libs_systemui
    platform_frameworks_native
    platform_frameworks_opt_net_wifi
    platform_hardware_google_pixel-sepolicy
    platform_libcore
    platform_manifest
    platform_packages_apps_Calendar
    platform_packages_apps_CarrierConfig
    platform_packages_apps_CellBroadcastReceiver
    platform_packages_apps_Contacts
    platform_packages_apps_Dialer
    platform_packages_apps_DocumentsUI
    platform_packages_apps_Gallery2
    platform_packages_apps_Launcher3
    platform_packages_apps_Messaging
    platform_packages_apps_Nfc
    platform_packages_apps_QuickSearchBox
    platform_packages_apps_RemoteProvisioner
    platform_packages_apps_Settings
    platform_packages_apps_SettingsIntelligence
    platform_packages_apps_ThemePicker
    platform_packages_apps_WallpaperPicker2
    platform_packages_inputmethods_LatinIME
    platform_packages_modules_Bluetooth
    platform_packages_modules_common
    platform_packages_modules_Connectivity
    platform_packages_modules_NetworkStack
    platform_packages_modules_Permission
    platform_packages_modules_Uwb
    platform_packages_modules_Wifi
    platform_packages_providers_DownloadProvider
    platform_packages_providers_MediaProvider
    platform_system_ca-certificates
    platform_system_core
    platform_system_extras
    platform_system_sepolicy
    platform_system_timezone
)

declare -A kernels=(
    # April 2023
    [kernel_build-coral]=android-13.0.0_r0.66
    [kernel_msm-coral]=android-13.0.0_r0.66
    [kernel_msm-extra-coral]=android-13.0.0_r0.66

    # April 2023
    [kernel_build-redbull]=android-13.0.0_r0.67
    [kernel_msm-redbull]=android-13.0.0_r0.67
    [kernel_msm-modules_qcacld-redbull]=android-13.0.0_r0.67
    [kernel_msm-extra-redbull]=android-13.0.0_r0.67

    # April 2023
    [kernel_build-gs101]=android-13.0.0_r0.68
    [kernel_gs-gs101]=android-13.0.0_r0.68
    [kernel_google-modules_gpu-gs101]=android-13.0.0_r0.68
    [kernel_google-modules_wlan_bcmdhd_bcm4389-gs101]=android-13.0.0_r0.68

    # April 2023
    [kernel_build-pantah]=android-13.0.0_r0.70
    [kernel_gs-pantah]=android-13.0.0_r0.70
    [kernel_google-modules_gpu-pantah]=android-13.0.0_r0.70
    [kernel_google-modules_wlan_bcmdhd_bcm4389-pantah]=android-13.0.0_r0.70
)

independent=(
    adevtool
    branding
    carriersettings-extractor
    device_google_bluejay-kernel
    device_google_coral-kernel
    device_google_pantah-kernel
    device_google_raviole-kernel
    device_google_redbull-kernel
    device_google_sunfish-kernel
    hardened_malloc
    kernel_common-5.10
    kernel_common-5.15
    kernel_manifest-5.10
    kernel_manifest-5.15
    kernel_manifest-bluejay
    kernel_manifest-coral
    kernel_manifest-pantah
    kernel_manifest-raviole
    kernel_manifest-redbull
    platform_external_Apps
    platform_external_Auditor
    platform_external_Camera
    platform_external_GmsCompatConfig
    platform_external_PdfViewer
    platform_external_seedvault
    platform_external_talkback
    platform_external_vanadium
    platform_packages_apps_DeskClock # temporarily based on AOSP 11 instead of AOSP 13
    platform_packages_apps_ExactCalculator
    platform_packages_apps_GmsCompat
    platform_packages_apps_SetupWizard
    platform_packages_apps_Updater
    platform_themes
    script
    vendor_state
)

for repo in "${aosp_forks[@]}"; do
    echo -e "\n>>> $(tput setaf 3)Handling $repo$(tput sgr0)"

    cd $repo

    git checkout $branch

    if [[ -n $DELETE_TAG ]]; then
        git tag -d $DELETE_TAG || true
        git push origin --delete $DELETE_TAG || true
        cd ..
        continue
    fi

    if [[ -n $build_number ]]; then
        if [[ $repo == platform_manifest ]]; then
            git checkout -B tmp
            sed -i s%refs/heads/$branch%refs/tags/$aosp_version.$build_number% default.xml
            git commit default.xml -m $aosp_version.$build_number
            git push -fu origin tmp
        else
            git tag -s $aosp_version.$build_number -m $aosp_version.$build_number
            git push origin $aosp_version.$build_number
        fi
    else
        git fetch upstream --tags

        git pull --rebase upstream $aosp_tag
        git push -f
    fi

    cd ..
done

for repo in ${!kernels[@]}; do
    echo -e "\n>>> $(tput setaf 3)Handling $repo$(tput sgr0)"

    cd $repo
    git checkout $branch

    if [[ -n $DELETE_TAG ]]; then
        git tag -d $DELETE_TAG || true
        git push origin --delete $DELETE_TAG || true
        cd ..
        continue
    fi

    if [[ -n $build_number ]]; then
        git tag -s $aosp_version.$build_number -m $aosp_version.$build_number
        git push origin $aosp_version.$build_number
    else
        git fetch upstream --tags
        kernel_tag=${kernels[$repo]}
        if [[ -z $kernel_tag ]]; then
            cd ..
            continue
        fi

        git checkout $branch
        git rebase $kernel_tag
        git push -f
    fi

    cd ..
done

for repo in ${independent[@]}; do
    echo -e "\n>>> $(tput setaf 3)Handling $repo$(tput sgr0)"

    cd $repo
    git checkout $branch

    if [[ -n $DELETE_TAG ]]; then
        git tag -d $DELETE_TAG || true
        git push origin --delete $DELETE_TAG || true
        cd ..
        continue
    fi

    if [[ -n $build_number ]]; then
        if [[ $repo == @(kernel_manifest-5.10|kernel_manifest-5.15|kernel_manifest-bluejay|kernel_manifest-coral|kernel_manifest-pantah|kernel_manifest-redbull|kernel_manifest-raviole) ]]; then
            git checkout -B tmp
            sed -i s%refs/heads/$branch%refs/tags/$aosp_version.$build_number% default.xml
            git commit default.xml -m $aosp_version.$build_number
            git push -fu origin tmp
        else
            git tag -s $aosp_version.$build_number -m $aosp_version.$build_number
            git push origin $aosp_version.$build_number
        fi
    else
        git push -f
    fi

    cd ..
done
