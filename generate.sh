#
# SPDX-FileCopyrightText: 2024 The Evolution X Project
#
# SPDX-License-Identifier: Apache-2.0
#

#!/bin/bash

certificates=(
    bluetooth
    cts_uicc_2021
    cyngn-app
    media
    networkstack
    nfc
    platform
    sdk_sandbox
    shared
    testcert
    testkey
    verity
)

apex_certificates=(
    com.android.adbd
    com.android.adservices.api
    com.android.adservices
    com.android.appsearch
    com.android.art
    com.android.bluetooth
    com.android.btservices
    com.android.cellbroadcast
    com.android.compos
    com.android.configinfrastructure
    com.android.connectivity.resources
    com.android.conscrypt
    com.android.devicelock
    com.android.extservices
    com.android.graphics.pdf
    com.android.hardware.biometrics.face.virtual
    com.android.hardware.biometrics.fingerprint.virtual
    com.android.hardware.boot
    com.android.hardware.cas
    com.android.hardware.wifi
    com.android.healthfitness
    com.android.hotspot2.osulogin
    com.android.i18n
    com.android.ipsec
    com.android.media
    com.android.mediaprovider
    com.android.media.swcodec
    com.android.nearby.halfsheet
    com.android.networkstack.tethering
    com.android.neuralnetworks
    com.android.ondevicepersonalization
    com.android.os.statsd
    com.android.permission
    com.android.resolv
    com.android.rkpd
    com.android.runtime
    com.android.safetycenter.resources
    com.android.scheduling
    com.android.sdkext
    com.android.support.apexer
    com.android.telephony
    com.android.telephonymodules
    com.android.tethering
    com.android.tzdata
    com.android.uwb
    com.android.uwb.resources
    com.android.virt
    com.android.vndk.current
    com.android.wifi
    com.android.wifi.dialog
    com.android.wifi.resources
    com.google.pixel.camera.hal
    com.google.pixel.vibrator.hal
    com.qorvo.uwb
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

    generate_certificates
}

generate_certificates() {
    echo "Generating certificates..."
    local generated=false

    for certificate in "${certificates[@]}" "${apex_certificates[@]}"; do
        if [[ (-f "${certificate}.x509.pem" && -f "${certificate}.pk8") ||
              (-f "${certificate}.certificate.override.x509.pem" && -f "${certificate}.certificate.override.pk8") ]]; then
            echo "$certificate already exists. Skipping..."
        else
            generated=true
            if [[ " ${certificates[*]} " == *" $certificate "* ]]; then
                size=$key_size
            else
                size=4096
                certificate="$certificate.certificate.override"
            fi
            echo | bash <(sed "s/2048/$size/" ../../../development/tools/make_key) \
                "$certificate" \
                "$subject"
        fi
    done

    if ! $generated; then
        echo "No new keys were generated. Exiting..."
        return
    fi

    create_symlinks
    generate_android_bp
    generate_keys_mk
}

create_symlinks() {
    echo "Creating system links..."
    rm -f BUILD.bazel releasekey.pk8 releasekey.x509.pem
    ln -sf ../../../build/make/target/product/security/BUILD.bazel BUILD.bazel
    ln -sf testkey.pk8 releasekey.pk8
    ln -sf testkey.x509.pem releasekey.x509.pem
}

generate_android_bp() {
    echo "Generating Android.bp..."
    rm -f Android.bp
    for apex_certificate in "${apex_certificates[@]}"; do
        echo "android_app_certificate {" >> Android.bp
        echo "    name: \"$apex_certificate.certificate.override\"," >> Android.bp
        echo "    certificate: \"$apex_certificate.certificate.override\"," >> Android.bp
        echo "}" >> Android.bp
        if [[ $apex_certificate != "${apex_certificates[-1]}" ]]; then
            echo >> Android.bp
        fi
    done
}

generate_keys_mk() {
    echo "Generating keys.mk..."
    rm -f keys.mk
    echo "PRODUCT_CERTIFICATE_OVERRIDES := \\" > keys.mk
    for apex_certificate in "${apex_certificates[@]}"; do
        if [[ $apex_certificate != "${apex_certificates[-1]}" ]]; then
            echo "    ${apex_certificate}:${apex_certificate}.certificate.override \\" >> keys.mk
        else
            echo "    ${apex_certificate}:${apex_certificate}.certificate.override" >> keys.mk
        fi
    done

    echo >> keys.mk
    echo "PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/testkey" >> keys.mk
    echo "PRODUCT_EXTRA_RECOVERY_KEYS :=" >> keys.mk
}

user_input
