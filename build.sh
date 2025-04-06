#!/bin/bash
set -e

export CONFIG="gtneo6se"
export ANYKERNEL_BRANCH="android14-6.1"
export SUSFS_BRANCH="gki-android14-6.1"
export SUSFS_VERSION="v1.5.5"

sudo apt-get update
sudo apt-get install -y git curl zip perl make gcc python3

mkdir -p ./git-repo
curl -o ./git-repo/repo https://storage.googleapis.com/git-repo-downloads/repo
chmod a+x ./git-repo/repo

mkdir -p "$CONFIG"
cd "$CONFIG"
../git-repo/repo init -u https://github.com/LinMoyu233/kernel_manifest.git \
    -b realme/sm7675 -m ${CONFIG}.xml --depth=1
../git-repo/repo sync -c -j$(nproc --all) --no-tags --fail-fast

cd kernel_platform
rm common/android/abi_gki_protected_exports_* || echo "No protected exports!"
rm msm-kernel/android/abi_gki_protected_exports_* || echo "No protected exports!"
sed -i 's|echo "\$res"|echo "-android14-11-o-v$(date +%Y%m%d)"|' common/scripts/setlocalversion
sed -i 's|echo "\$res"|echo "-android14-11-o-v$(date +%Y%m%d)"|' msm-kernel/scripts/setlocalversion
sed -i 's/ -dirty//g' external/dtc/scripts/setlocalversion
sed -i 's/SUBLEVEL = 68/SUBLEVEL = 75/' msm-kernel/Makefile

curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -
cd KernelSU-Next
export KSU_VERSION=$(expr $(/usr/bin/git rev-list --count HEAD) "+" 10200)
export KSUVER=$KSU_VERSION

cd ../../
git clone https://gitlab.com/simonpunk/susfs4ksu.git -b "$SUSFS_BRANCH" --depth=1
git clone https://github.com/TheWildJames/kernel_patches.git  --depth=1

cd kernel_platform
cp ../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU-Next/
cp ../susfs4ksu/kernel_patches/50_add_susfs_in_gki-${ANYKERNEL_BRANCH}.patch common/
cp ../kernel_patches/KernelSU-Next-Implement-SUSFS-${SUSFS_VERSION}-Universal.patch ./KernelSU-Next/
cp ../susfs4ksu/kernel_patches/fs/* ./common/fs/
cp ../susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/

cd KernelSU-Next
patch -p1 < KernelSU-Next-Implement-SUSFS-${SUSFS_VERSION}-Universal.patch || true
cd ../common
patch -p1 < 50_add_susfs_in_gki-${ANYKERNEL_BRANCH}.patch || true
cp ../../kernel_patches/69_hide_stuff.patch ./
patch -p1 -F 3 < 69_hide_stuff.patch
patch -p1 < ../../.repo/manifests/patches/001-lz4.patch
patch -p1 < ../../.repo/manifests/patches/002-zstd.patch

cd ../../
./kernel_platform/oplus/build/oplus_build_kernel.sh pineapple gki

git clone https://github.com/Kernel-SU/AnyKernel3 --depth=1
rm -rf ./AnyKernel3/.git
cp kernel_workspace/kernel_platform/out/msm-kernel-pineapple-gki/dist/Image ./AnyKernel3/
cd AnyKernel3
ZIP_NAME="Anykernel3-${CONFIG}-android14-11-o-v$(date +%Y%m%d).zip"
zip -r "../$ZIP_NAME" ./*
