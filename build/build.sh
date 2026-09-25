#!/bin/bash

set -e

if [ "$1" == "--local-aapt" ];then
    export LD_LIBRARY_PATH=.
    export PATH=.:$PATH
    shift
fi

script_dir="$(dirname "$(readlink -f -- "$0")")"
if [ "$#" -eq 1 ]; then
    if [ -d "$1" ];then
	    makes="$(find "$1" -name Android.mk -exec readlink -f -- '{}' \;)"

    else
	    makes="$(readlink -f -- "$1")"
    fi
else
    cd "$script_dir"
    makes="$(find "$PWD/.." -name Android.mk)"
fi

if ! command -v aapt > /dev/null;then
    export LD_LIBRARY_PATH=.
    export PATH=$PATH:.
fi

if ! command -v zip > /dev/null;then
    echo "Please install zip (apt install zip should do)"
    exit 1
fi

if ! command -v aapt > /dev/null;then
    echo "Please install aapt (apt install aapt should do)"
    exit 1
fi

cd "$script_dir"

BUILD_TYPE="${BUILD_TYPE:-apk}"

if [ "$BUILD_TYPE" = "ksu" ];then
    echo "Building KSU module..."
    rm -rf ksu_build
    mkdir -p ksu_build/system/product/overlay
    cp -r ../ksu/module.prop ksu_build/module.prop 2>/dev/null || true
    cp -r ../ksu/update.json ksu_build/update.json 2>/dev/null || true
fi

echo "$makes" | while read -r f;do
    name="$(sed -nE 's/LOCAL_PACKAGE_NAME.*:\=\s*(.*)/\1/p' "$f")"
    grep -q treble-overlay <<<"$name" || continue
    echo "Generating $name"

    path="$(dirname "$f")"
    aapt package -f -F "${name}-unsigned.apk" -M "$path/AndroidManifest.xml" -S "$path/res" -I android.jar
    if [ "$name" = "treble-overlay-tecno-spark20" ];then
	    LD_LIBRARY_PATH=./signapk/ java -jar signapk/signapk.jar keys/debug.x509.pem keys/debug.pk8 "${name}-unsigned.apk" "${name}.apk"
	else
	    LD_LIBRARY_PATH=./signapk/ java -jar signapk/signapk.jar keys/platform.x509.pem keys/platform.pk8 "${name}-unsigned.apk" "${name}.apk"
	fi
    rm -f "${name}-unsigned.apk"
    if [ "$BUILD_TYPE" = "ksu" ];then
	    cp "${name}.apk" "ksu_build/system/product/overlay/${name}.apk"
    fi
done

if [ "$BUILD_TYPE" = "ksu" ];then
    echo "Creating KSU module zip..."
    cd ksu_build
    zip -r ../tecno-kj5-overlays-ksu-module.zip .
    cd ..
    echo "KSU module created: tecno-kj5-overlays-ksu-module.zip"
fi
