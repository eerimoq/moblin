#!/bin/bash

set -e
set -o pipefail

if [ ! -e OpenSSL ] ; then
  git clone git@github.com:krzyzanowskim/OpenSSL.git
fi

if [ ! -e srt ] ; then
  git clone git@github.com:eerimoq/srt.git
  pushd srt
  git checkout moblin
  popd
fi

srt() {
  IOS_OPENSSL=$(pwd)/OpenSSL/$1

  mkdir -p ./build/$2/$3
  pushd ./build/$2/$3
  ../../../srt/configure --cmake-prefix-path=$IOS_OPENSSL --ios-disable-bitcode=1 --ios-platform=$2 --ios-arch=$3 --cmake-toolchain-file=scripts/iOS.cmake --USE_OPENSSL_PC=off --enable-maxrexmitbw=ON
  make -j $(nproc)
  popd
}

# iOS
export IPHONEOS_DEPLOYMENT_TARGET=16.4
SDKVERSION=$(xcrun --sdk iphoneos --show-sdk-version)
srt iphonesimulator SIMULATOR64 x86_64
srt iphonesimulator SIMULATOR64 arm64
srt iphoneos OS arm64

rm -f ./build/SIMULATOR64/libsrt-lipo.a
lipo -create ./build/SIMULATOR64/arm64/libsrt.a ./build/SIMULATOR64/x86_64/libsrt.a -output ./build/SIMULATOR64/libsrt-lipo.a
libtool -static -o ./build/SIMULATOR64/libsrt.a ./build/SIMULATOR64/libsrt-lipo.a ./OpenSSL/iphonesimulator/lib/libcrypto.a ./OpenSSL/iphonesimulator/lib/libssl.a

rm -f ./build/OS/libsrt-lipo.a
lipo -create ./build/OS/arm64/libsrt.a -output ./build/OS/libsrt-lipo.a
libtool -static -o ./build/OS/libsrt.a ./build/OS/libsrt-lipo.a ./OpenSSL/iphoneos/lib/libcrypto.a ./OpenSSL/iphoneos/lib/libssl.a

# Copies too many files
cp srt/srtcore/*.h Includes
cp ./build/OS/arm64/version.h Includes/version.h

echo "#define ENABLE_MAXREXMITBW 1" >> Includes/platform_sys.h

# make libsrt.xcframework
rm -rf libsrt.xcframework
xcodebuild -create-xcframework \
    -library ./build/SIMULATOR64/libsrt.a -headers Includes \
    -library ./build/OS/libsrt.a -headers Includes \
    -output libsrt.xcframework
