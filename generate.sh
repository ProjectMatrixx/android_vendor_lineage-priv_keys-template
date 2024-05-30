#!/bin/bash
#
# SPDX-FileCopyrightText: 2024 The Evolution X Project
#
# SPDX-License-Identifier: Apache-2.0
#

files=(
    bluetooth
    cts_uicc_2021
    cyngn-app
    media
    networkstack
    platform
    sdk_sandbox
    shared
    testcert
    testkey
    verity
)

apex=(
    com.android.adbd.certificate.override
    com.android.adservices.api.certificate.override
    com.android.adservices.certificate.override
    com.android.appsearch.certificate.override
    com.android.art.certificate.override
    com.android.bluetooth.certificate.override
    com.android.btservices.certificate.override
    com.android.cellbroadcast.certificate.override
    com.android.compos.certificate.override
    com.android.configinfrastructure.certificate.override
    com.android.connectivity.resources.certificate.override
    com.android.conscrypt.certificate.override
    com.android.devicelock.certificate.override
    com.android.extservices.certificate.override
    com.android.graphics.pdf.certificate.override
    com.android.hardware.biometrics.face.virtual.certificate.override
    com.android.hardware.biometrics.fingerprint.virtual.certificate.override
    com.android.hardware.boot.certificate.override
    com.android.hardware.cas.certificate.override
    com.android.hardware.wifi.certificate.override
    com.android.healthfitness.certificate.override
    com.android.hotspot2.osulogin.certificate.override
    com.android.i18n.certificate.override
    com.android.ipsec.certificate.override
    com.android.media.certificate.override
    com.android.mediaprovider.certificate.override
    com.android.media.swcodec.certificate.override
    com.android.nearby.halfsheet.certificate.override
    com.android.networkstack.tethering.certificate.override
    com.android.neuralnetworks.certificate.override
    com.android.ondevicepersonalization.certificate.override
    com.android.os.statsd.certificate.override
    com.android.permission.certificate.override
    com.android.resolv.certificate.override
    com.android.rkpd.certificate.override
    com.android.runtime.certificate.override
    com.android.safetycenter.resources.certificate.override
    com.android.scheduling.certificate.override
    com.android.sdkext.certificate.override
    com.android.support.apexer.certificate.override
    com.android.telephony.certificate.override
    com.android.telephonymodules.certificate.override
    com.android.tethering.certificate.override
    com.android.tzdata.certificate.override
    com.android.uwb.certificate.override
    com.android.uwb.resources.certificate.override
    com.android.virt.certificate.override
    com.android.vndk.current.certificate.override
    com.android.wifi.certificate.override
    com.android.wifi.dialog.certificate.override
    com.android.wifi.resources.certificate.override
    com.google.pixel.camera.hal.certificate.override
    com.google.pixel.vibrator.hal.certificate.override
    com.qorvo.uwb.certificate.override
)

confirm() {
    while true; do
        read -r -p "$1 (yes/no): " input
        case "$input" in
            [yY][eE][sS]|[yY]) echo "yes"; return ;;
            [nN][oO]|[nN]) echo "no"; return ;;
            *) ;;
        esac
    done
}

prompt_key_size() {
    while true; do
        read -p "$1" input
        if [[ "$input" == "2048" || "$input" == "4096" ]]; then
            echo "$input"
            break
        fi
    done
}

prompt() {
    while true; do
        read -p "$1" input
        if [[ -n "$input" ]]; then
            echo "$input"
            break
        fi
    done
}

user_input() {
    if [[ $(confirm "Do you want to customize the key size and subject?") == "yes" ]]; then
        key_size=$(prompt_key_size "Enter the key size (2048 or 4096, APEX will always use 4096): ")
        country_code=$(prompt "Enter the country code (e.g., US): ")
        state=$(prompt "Enter the state or province (e.g., California): ")
        city=$(prompt "Enter the city or locality (e.g., Mountain View): ")
        org=$(prompt "Enter the organization (e.g., Android): ")
        ou=$(prompt "Enter the organizational unit (e.g., Android): ")
        cn=$(prompt "Enter the common name (e.g., Android): ")
        email=$(prompt "Enter the email address (e.g., android@android.com): ")

        echo "Subject information to be used:"
        echo "Key Size: $key_size"
        echo "Country Code: $country_code"
        echo "State/Province: $state"
        echo "City/Locality: $city"
        echo "Organization (O): $org"
        echo "Organizational Unit (OU): $ou"
        echo "Common Name (CN): $cn"
        echo "Email Address: $email"

        if [[ $(confirm "Is this information correct?") != "yes" ]]; then
            echo "Generation aborted."
            exit 0
        fi
    else
        key_size='2048'
        country_code='US'
        state='California'
        city='Mountain View'
        org='Android'
        ou='Android'
        cn='Android'
        email='android@android.com'
    fi

    subject="/C=$country_code/ST=$state/L=$city/O=$org/OU=$ou/CN=$cn/emailAddress=$email"
}

generate_keys() {
    echo "Generating keys..."
    for file in "${files[@]}" "${apex[@]}"; do
        if [[ "${files[*]}" =~ "${file}" ]]; then
            size=$key_size
        else
            size=4096
        fi
        echo | bash <(sed "s/2048/$size/" ../../../development/tools/make_key) \
            "$file" \
            "$subject"
    done
}

create_symlinks() {
    echo "Creating system links..."
    ln -sf ../../../build/make/target/product/security/BUILD.bazel BUILD.bazel
    ln -sf testkey.pk8 releasekey.pk8
    ln -sf testkey.x509.pem releasekey.x509.pem
}

generate_android_bp() {
    echo "Generating Android.bp..."
    for apex_file in "${apex[@]}"; do
        echo "android_app_certificate {" >> Android.bp
        echo "    name: \"$apex_file\"," >> Android.bp
        echo "    certificate: \"$apex_file\"," >> Android.bp
        echo "}" >> Android.bp
        if [[ $apex_file != "${apex[-1]}" ]]; then
            echo >> Android.bp
        fi
    done
}

generate_keys_mk() {
    echo "Generating keys.mk..."
    echo "PRODUCT_CERTIFICATE_OVERRIDES := \\" > keys.mk
    for apex_file in "${apex[@]}"; do
        apex_name="${apex_file%.certificate.override}"
        if [[ $apex_file != "${apex[-1]}" ]]; then
            echo "    ${apex_name}:${apex_file} \\" >> keys.mk
        else
            echo "    ${apex_name}:${apex_file}" >> keys.mk
        fi
    done

    echo >> keys.mk
    echo "PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/testkey" >> keys.mk
    echo "PRODUCT_EXTRA_RECOVERY_KEYS :=" >> keys.mk
}

user_input
generate_keys
create_symlinks
generate_android_bp
generate_keys_mk

rm -rf .git
rm README.md
rm "$0"
