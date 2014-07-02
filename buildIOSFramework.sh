#!/bin/sh
#
# OpenSSL Framework for iOS build script
# Andrey Timofeev, cppguru.com, October, 2013
#
# NOTE: ARMv7 is available since S5L8920 ( iPhone 3GS )
# So I see no reason to support armv6
#
ARCHS="i386 x86_64 armv7 armv7s arm64"
VERSION="1.0.1h"
SDKVER="7.1"
CP=`pwd`
COMPILER="clang"
DEVHOME=`xcode-select -print-path`
 
#
# Downloading OpenSSL
#
set -e
if [ ! -e openssl-${VERSION}.tar.gz ]; then
  curl -O http://www.openssl.org/source/openssl-${VERSION}.tar.gz
fi
 
mkdir -p "${CP}/src"
mkdir -p "${CP}/bin"
mkdir -p "${CP}/lib"
 
tar zxf openssl-${VERSION}.tar.gz -C "${CP}/src"
cd "${CP}/src/openssl-${VERSION}"
 
for ARCH in ${ARCHS}
do
  if [[ "${ARCH}" == "i386" ]];
  then
    PLATFORM="iPhoneSimulator"
    PA=""
  elif [[ "${ARCH}" == "x86_64" ]];
  then
    PLATFORM="iPhoneSimulator"
    PA="-DOPENSSL_NO_ASM"
  else
    PLATFORM="iPhoneOS"
    PA=""
    sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" \
      "crypto/ui/ui_openssl.c"
  fi
  export CROSS_TOP="${DEVHOME}/Platforms/${PLATFORM}.platform/Developer"
  export CROSS_SDK="${PLATFORM}${SDKVER}.sdk"
  export BUILD_TOOLS="${DEVHOME}/Platforms/${PLATFORM}.platform/Developer"
  echo "Building openssl-${VERSION} for ${PLATFORM} ${SDKVER} ${ARCH}"
  export CC="${DEVHOME}/Toolchains/XcodeDefault.xctoolchain/usr/bin/${COMPILER} -arch ${ARCH} ${PA}"
  mkdir -p "${CP}/bin/${PLATFORM}${SDKVER}-${ARCH}.sdk"
 
  #
  # Configuring OpenSSL
  #
  ./Configure iphoneos-cross --openssldir="${CP}/bin/${PLATFORM}${SDKVER}-${ARCH}.sdk"
  sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP} -miphoneos-version-min=4.3 !" "Makefile"
 
  #
  # Building OpenSSL
  #
  make
  make install
  make clean
done
 
#
# Creating OpenSSL Framework
#
FW_DIR=${CP}/framework
FW_BUNDLE=${FW_DIR}/openssl.framework
 
#
# Setting up directories
#
rm -rf ${FW_DIR}
mkdir -p ${FW_DIR}
mkdir -p ${FW_BUNDLE}
mkdir -p ${FW_BUNDLE}/Headers
 
#
# Lipoing libraries
#
for ARCH in ${ARCHS}
do
  if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]];
  then
    PLATFORM="iPhoneSimulator"
  else
    PLATFORM="iPhoneOS"
  fi
  LIPSTR=${LIPSTR}" "${CP}/lib/openssl-${ARCH}.a
  libtool -static -o "${CP}/lib/openssl-${ARCH}.a" \
    "${CP}/bin/${PLATFORM}${SDKVER}-${ARCH}.sdk/lib/libcrypto.a" \
    "${CP}/bin/${PLATFORM}${SDKVER}-${ARCH}.sdk/lib/libssl.a"
done
 
#
# Lipoing libs together
#
lipo -create ${LIPSTR} -output "${CP}/lib/openssl"
cp "${CP}/lib/openssl" ${FW_BUNDLE}/openssl
 
#
# Copying includes
#
cp -R ${CP}/bin/iPhoneSimulator${SDKVER}-i386.sdk/include/openssl/* ${FW_BUNDLE}/Headers/
  
rm -rf ${CP}/src/openssl-${VERSION}
rm -rf ${CP}/include
rm -rf ${CP}/lib
rm -rf ${CP}/src
rm -rf ${CP}/bin
 
echo "Done!"