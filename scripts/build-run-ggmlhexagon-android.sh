#!/usr/bin/env bash
#
# This single-source file is part of JZ's ggml-hexagon.
# 2024--2026 The ggml authors
# GitHub:  https://github.com/zhouwg/ggml-hexagon
# Any copies or derivative works of this file shall preserve the above attribution information,
# including the copyright notice and the GitHub repository URL.
#
# this script will setup local dev envs automatically and docker is not needed for purpose of simplify workflow.
#
# this script is AI Agent friendly and verified with Trae AI Agent.
#
# 1. build&verify llama.cpp + JZ's ggml-hexagon backend(libggmldsp-skel.so) on Linux for Android phone equipped with Qualcomm Snapdragon mobile SoC(8Elite is recommended)
#
# 2. build&verify llama.cpp + Qualcomm's ggml-hexagon backend(libggml-htp.so) on Linux for Android phone equipped with Qualcomm Snapdragon mobile SoC(8Elite is recommended)
#
# 3. performance comparison of Qualcomm's ggml-hexagon and JZ's ggml-hexagon on Android phone equipped with Qualcomm Snapdragon mobile SoC(8Elite is recommended & verified)
#
#
set -e

######## part-1: public macros & vars ########

PWD=`pwd`
PROJECT_HOME_PATH=`pwd`
PROJECT_ROOT_PATH=${PROJECT_HOME_PATH}
HOST_CPU_COUNTS=`cat /proc/cpuinfo | grep "processor" | wc | awk '{print int($1)}'`

VERBOSE=OFF
VERBOSE=ON

#running path on Android phone
REMOTE_PATH=/data/local/tmp

#path of built artifacts
LOCAL_BUILD_DIR=${PROJECT_ROOT_PATH}/out/ggmlhexagon-android

#path of toolchain, for purpose of share same toolchain in multiple instance of ggml-hexagon
TOOLCHAIN_PATH=${PROJECT_ROOT_PATH}/prebuilts
#TOOLCHAIN_PATH=/home/zhouwg/develop/ggml-hexagon/prebuilts

#Android NDK can be found at:
#https://developer.android.com/ndk/downloads
ANDROID_PLATFORM=android-34
ANDROID_NDK_VERSION=r28
ANDROID_NDK_NAME=android-ndk-${ANDROID_NDK_VERSION}
ANDROID_NDK_FULLNAME=${ANDROID_NDK_NAME}-linux.zip
ANDROID_NDK=${TOOLCHAIN_PATH}/${ANDROID_NDK_NAME}

# --- Define NDK paths based on the absolute SDK path ---
NDK_TOOLCHAIN_SYSROOT_INCLUDE_PATH="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include"
NDK_TOOLCHAIN_SYSROOT_ARM64_LIB_PATH="${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android"

#OpenCL Headers can be found at:
#https://https://github.com/KhronosGroup/OpenCL-Headers
OPENCL_SDK_URL=https://github.com/KhronosGroup/OpenCL-Headers
OPENCL_SDK_PATH=${TOOLCHAIN_PATH}/OpenCL_SDK
OPENCL_HEADERS_PATH=${OPENCL_SDK_PATH}/OpenCL-Headers

#fully Qualcomm Hexagon SDK can be found at https://developer.qualcomm.com/software/hexagon-dsp-sdk/tools.
#fully Hexagon SDK must be obtained with Qualcomm Developer Account and follow PKLA&ECA.
HEXAGON_SDK_VERSION=6.6.0.0
HEXAGON_TOOLS_VERSION=19.0.07
HEXAGON_SDK_PATH=${TOOLCHAIN_PATH}/Hexagon_SDK/${HEXAGON_SDK_VERSION}
HEXAGON_TOOLS_PATH=${HEXAGON_SDK_PATH}/tools/HEXAGON_Tools/${HEXAGON_TOOLS_VERSION}

#supported htp arch version:
#v73 --- Snapdragon 8 Gen2
#v75 --- Snapdragon 8 Gen3
#v79 --- Snapdragon 8 Elite(aka 8 Gen4)
#v81 --- Snapdragon 8 Elite Gen5(aka 8 Gen5)

#Qualcomm Snapdragon 8Elite based Android phone is strongly recommended because:
#1. sometimes the same dsp codes can got the best performance on Snapdragon 8Elite based phone.
#2. DSP clock rate on 8Gen3 is slower than DSP clock rate on 8Elite.
#3. 8Elite support for LP-DDR5x memory, up to 5300 MHz; 8Gen3 support for LP-DDR5x memory, up to 4800 MHz.

#HTP_ARCH_VERSIONS="v79"                         # 8 Elite
#HTP_ARCH_VERSIONS="v79 v75"                     # 8 Elite + 8Gen3
HTP_ARCH_VERSIONS="v73 v75 v79 v81"              # all

# default HTP_ARCH
HTP_ARCH_VERSION=${HTP_ARCH_VERSIONS%% *}

######## part-2: prompt and LLM models ########

#the following LLM models has verified(works fine) with the JZ's ggml-hexagon backend on a Snapdragon 8Elite based Android phone
#1.12 GiB, will be downloadded automatically via this script when running this script at the first time
GGUF_MODEL_NAME=/sdcard/qwen1_5-1_8b-chat-q4_0.gguf

#1.2 GiB, will be downloadded automatically via this script when running this script at the first time
GGUF_MODEL_NAME=/sdcard/Qwen3.5-2B-Q4_0.gguf

#2.5 GiB, will be downloadded automatically via this script when running this script at the first time
GGUF_MODEL_NAME=/sdcard/Qwen3.5-4B-Q4_0.gguf

#5.1 GiB, will be downloadded automatically via this script when running this script at the first time
GGUF_MODEL_NAME=/sdcard/Qwen3.5-9B-Q4_0.gguf

#737 MiB, will be downloadded automatically via this script when running this script at the first time
GGUF_MODEL_NAME=/sdcard/Llama-3.2-1B-Instruct-Q4_0.gguf

#2.9 GiB, will be downloadded automatically via this script when running this script at the first time
GGUF_MODEL_NAME=/sdcard/gemma-4-E2B-it-Q4_0.gguf

# Model aliases for quick testing of multiple models
# Usage: ./scripts/build-run-ggmlhexagon-android.sh run_llamacli <alias>
#   qwen3-2b    -> Qwen3.5-2B-Q4_0.gguf
#   qwen3-4b    -> Qwen3.5-4B-Q4_0.gguf
#   qwen3-9b    -> Qwen3.5-9B-Q4_0.gguf
#   gemma4-e2b  -> gemma-4-E2B-it-Q4_0.gguf (2.9 GiB, fits entirely in ION mempool)
#   gemma4-e4b  -> gemma-4-E4B_q4_0-it.gguf (4.9 GiB, triggers mirror/eviction for stress testing)
#   qwen1       -> qwen1_5-1_8b-chat-q4_0.gguf
#   llama3      -> Llama-3.2-1B-Instruct-Q4_0.gguf
#   (default)   -> gemma-4-E2B-it-Q4_0.gguf
function resolve_model_name()
{
    case "$1" in
        qwen3-2b)   echo "/sdcard/Qwen3.5-2B-Q4_0.gguf" ;;
        qwen3-4b)   echo "/sdcard/Qwen3.5-4B-Q4_0.gguf" ;;
        qwen3-9b)   echo "/sdcard/Qwen3.5-9B-Q4_0.gguf" ;;
        gemma4-e2b) echo "/sdcard/gemma-4-E2B-it-Q4_0.gguf" ;;
        gemma4-e4b) echo "/sdcard/gemma-4-E4B_q4_0-it.gguf" ;;
        qwen1)      echo "/sdcard/qwen1_5-1_8b-chat-q4_0.gguf" ;;
        llama3)     echo "/sdcard/Llama-3.2-1B-Instruct-Q4_0.gguf" ;;
        *)          echo "" ; return 1 ;;
    esac
}

PROMPT_STRING="Hello, good morning, you are a powerful domain expert and know many things, now pls help to introduce the movie Once Upon a Time in America briefly, pls pay attention short then 1000 words\n"

#unified command-line parameters used during inference testing for fair performance comparison of PP and TG across Qualcomm's ggml-hexagon and JZ's ggml-hexagon
#running_params=" -ngl 99 -t 6 -n 256 --no-warmup --load-mode none --poll 1000 --cpu-mask 0xfc --cpu-strict 1 --ctx-size 8192 --ubatch-size 1024 -fa on"
running_params=" -ngl 99 -t 6 -n 256 --ctx-size 8192 --ubatch-size 64 --poll 1000 --no-warmup --load-mode none -fa on --jinja -st"

######## part-3: utilities and functions ########

function dump_vars()
{
    echo -e "ANDROID_NDK:          ${ANDROID_NDK}"
    echo -e "HEXAGON_SDK_PATH:     ${HEXAGON_SDK_PATH}"
}


function show_pwd()
{
    echo -e "current working path:$(pwd)\n"
}


function check_command_in_host()
{
    set +e
    cmd=$1
    if command -v ${cmd} > /dev/null 2>&1; then
        printf "${cmd} is available on host machine\n"
        echo ""
    else
        printf "${cmd} not exist on host machine, pls install command line utility ${cmd} firstly and accordingly\n"
        exit 1
    fi
    set -e
}


function check_commands_in_host()
{
    check_command_in_host wget
    check_command_in_host xzcat
    check_command_in_host adb
    check_command_in_host md5sum
    check_command_in_host ninja
}


function check_android_phone()
{
    local device_raw
    device_raw=$(adb devices 2>/dev/null | grep -v "List of devices" | awk 'NF>0')

    if [[ -z "$device_raw" ]]; then
        adb kill-server >/dev/null 2>&1
        sleep 0.1
        adb start-server >/dev/null 2>&1
        device_raw=$(adb devices 2>/dev/null | grep -v "List of devices" | awk 'NF>0')
        if [[ -z "$device_raw" ]]; then
            echo "No Android device detected."
            echo "Please check if phone is connected properly.Exiting"
            exit 1
        fi
    fi

    if echo "$device_raw" | grep -q "no permissions"; then
        echo "Device detected but has NO PERMISSIONS."
        echo "Please check if phone is connected properly.Exiting"
        exit 1
    fi

    if echo "$device_raw" | grep -q "unauthorized"; then
        echo "Device detected but UNAUTHORIZED."
        echo "Please check if phone is connected properly.Exiting"
        exit 1
    fi

    if echo "$device_raw" | grep -q "offline"; then
        echo "Device is OFFLINE."
        echo "Please check if phone is connected properly.Exiting"
        exit 1
    fi

    if echo "$device_raw" | awk '{print $2}' | grep -qx "device"; then
        local sn=$(echo "$device_raw" | awk '{print $1}')
        echo "Android device connected successfully: $sn"
        return 0
    fi

    echo "Unknown device error."
    echo "Please check if phone is connected properly.Exiting"
    exit 1
}


#TODO:refine this function
function check_and_download_hexagon_sdk()
{
    is_hexagon_llvm_exist=1
    if [ ! -f ${TOOLCHAIN_PATH}/Hexagon_SDK/${HEXAGON_SDK_VERSION}/tools/HEXAGON_Tools/${HEXAGON_TOOLS_VERSION}/NOTICE.txt ]; then
        echo -e "${TEXT_RED}minimal-hexagon-sdk not exist...${TEXT_RESET}\n"
        is_hexagon_llvm_exist=0
    fi

    if [ ${is_hexagon_llvm_exist} -eq 0 ]; then
        mkdir -p ${TOOLCHAIN_PATH}/Hexagon_SDK/
        if [ -f ${TOOLCHAIN_PATH}/Hexagon_SDK/hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz ]; then
            echo -e "hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz already exist\n"
        else
            echo -e "begin downloading hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz \n"
            wget --no-config --quiet --show-progress -O ${TOOLCHAIN_PATH}/Hexagon_SDK/hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz https://github.com/snapdragon-toolchain/hexagon-sdk/releases/download/v6.6.0.0/hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz
            if [ $? -ne 0 ]; then
                printf "failed to download hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz\n"
                exit 1
            fi
        fi

        echo -e "begin decompressing hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz \n"
        xzcat ${TOOLCHAIN_PATH}/Hexagon_SDK/hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz | tar -C ${TOOLCHAIN_PATH}/Hexagon_SDK/ -xf -
        if [ $? -ne 0 ]; then
            printf "failed to decompress hexagon-sdk-v6.6.0.0-amd64-lnx.tar.xz\n"
            exit 1
        fi
        printf "install minimal-hexagon-sdk successfully\n\n"
    fi

    if [ ! -d ${HEXAGON_SDK_PATH} ]; then
        echo -e "HEXAGON_SDK_PATH ${HEXAGON_SDK_PATH} not exist, pls install it accordingly...\n"
        exit 0
    else
        printf "Qualcomm Hexagon SDK already exist:${HEXAGON_SDK_PATH} \n\n"
    fi
}


function check_and_download_opencl_sdk()
{
    is_opencl_sdk_exist=1

    if [ ! -d ${OPENCL_SDK_PATH} ]; then
        echo -e "OPENCL_SDK_PATH ${OPENCL_SDK_PATH} not exist, download it from ${OPENCL_SDK_URL}...\n"
        is_opencl_sdk_exist=0
    fi
    if [ ! -f ${NDK_TOOLCHAIN_SYSROOT_ARM64_LIB_PATH}/libOpenCL.so ]; then
        echo -e "${NDK_TOOLCHAIN_SYSROOT_ARM64_LIB_PATH}/libOpenCL.so not exist...\n"
        is_opencl_sdk_exist=0
    fi

    if [ ${is_opencl_sdk_exist} -eq 0 ]; then
        mkdir -p ${OPENCL_SDK_PATH}
        cd ${OPENCL_SDK_PATH}

        if [ ! -d OpenCL-Headers ]; then
            echo "Cloning OpenCL-Headers..."
            git clone https://github.com/KhronosGroup/OpenCL-Headers
            if [ $? -ne 0 ]; then
                printf "failed to download OpenCL-Headers to %s \n" "${OPENCL_SDK_PATH}"
                exit 1
            fi
        fi
        cd ${TOOLCHAIN_PATH}/OpenCL_SDK/OpenCL-Headers
        printf "Copying OpenCL Headers to Android NDK sysroot include: ${NDK_TOOLCHAIN_SYSROOT_INCLUDE_PATH}"
        mkdir -p ${NDK_TOOLCHAIN_SYSROOT_INCLUDE_PATH}
        /bin/cp -r -fv CL ${NDK_TOOLCHAIN_SYSROOT_INCLUDE_PATH}

        cd ${TOOLCHAIN_PATH}/OpenCL_SDK
        if [ ! -d OpenCL-ICD-Loader ]; then
            echo "Cloning OpenCL-ICD-Loader..."
            git clone https://github.com/KhronosGroup/OpenCL-ICD-Loader
            if [ $? -ne 0 ]; then
                printf "failed to download OpenCL-ICD-Loader to %s \n" "${OPENCL_SDK_PATH}"
                exit 1
            fi
        fi
        cd ${TOOLCHAIN_PATH}/OpenCL_SDK/OpenCL-ICD-Loader
        mkdir -p build
        cd build
        cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=latest -DANDROID_STL=c++_shared -DOPENCL_ICD_LOADER_HEADERS_DIR=${NDK_TOOLCHAIN_SYSROOT_INCLUDE_PATH}
        echo "Building OpenCL-ICD-Loader with ninjia..."
        ninja
        if [ $? -ne 0 ]; then
            printf "failed to build OpenCL-ICD-Loader\n"
            exit 1
        fi
        mkdir -p ${NDK_TOOLCHAIN_SYSROOT_ARM64_LIB_PATH}
        /bin/cp -fv libOpenCL.so ${NDK_TOOLCHAIN_SYSROOT_ARM64_LIB_PATH}

        echo "OpenCL components setup complete"
        echo "OpenCL Headers are in: ${NDK_TOOLCHAIN_SYSROOT_INCLUDE_PATH}/CL"
        echo "libOpenCL.so is in:    ${NDK_TOOLCHAIN_SYSROOT_ARM64_LIB_PATH}/libOpenCL.so"

        cd ${PROJECT_ROOT_PATH}
    else
        printf "OpenCL SDK already exist:    ${OPENCL_SDK_PATH} \n\n"
    fi
}


function check_and_download_ndk()
{
    is_android_ndk_exist=1

    if [ ! -d ${ANDROID_NDK} ]; then
        is_android_ndk_exist=0
    fi

    if [ ! -f ${ANDROID_NDK}/build/cmake/android.toolchain.cmake ]; then
        is_android_ndk_exist=0
    fi

    if [ ${is_android_ndk_exist} -eq 0 ]; then

        if [ ! -f ${TOOLCHAIN_PATH}/${ANDROID_NDK_FULLNAME} ]; then
            wget --no-config --quiet --show-progress -O ${TOOLCHAIN_PATH}/${ANDROID_NDK_FULLNAME} https://dl.google.com/android/repository/${ANDROID_NDK_FULLNAME}
        fi

        cd ${TOOLCHAIN_PATH}
        unzip ${ANDROID_NDK_FULLNAME}

        if [ $? -ne 0 ]; then
            printf "failed to download Android NDK to %s \n" "${ANDROID_NDK}"
            exit 1
        fi
        cd ${PROJECT_ROOT_PATH}

        printf "Android NDK saved to ${ANDROID_NDK} \n\n"
    else
        printf "Android NDK already exist:         ${ANDROID_NDK} \n\n"
    fi
}


function build_idl()
{
    echo "build idl"
    if [ -f ${HEXAGON_SDK_PATH}/ipc/fastrpc/qaic/bin/qaic ]; then
        ${HEXAGON_SDK_PATH}/ipc/fastrpc/qaic/bin/qaic -mdll -o ${PROJECT_ROOT_PATH}/ggml/src/ggml-hexagon/kernels -I${HEXAGON_SDK_PATH}/incs -I${HEXAGON_SDK_PATH}/incs/stddef -I${HEXAGON_SDK_PATH}/ipc/fastrpc/incs ${PROJECT_ROOT_PATH}/ggml/src/ggml-hexagon/kernels/ggml_dsp.idl
    fi
}


#build extra DSP skels (all HTP_ARCH_VERSIONS except the first/default)
#$1 = "debug" for debug build, anything else for release build
function build_extra_dsp_skels()
{
    local dsp_debug_flag
    if [ "$1" == "debug" ]; then
        dsp_debug_flag="-DDEBUG -Wall"
    else
        dsp_debug_flag="-DNDEBUG -Wall"
    fi

    # extras = HTP_ARCH_VERSIONS minus the first element (default)
    for extra_ver in ${HTP_ARCH_VERSIONS#* }; do
        printf "\n========== build extra DSP skel: libggmldsp-skel-${extra_ver}.so ==========\n"
        build_idl
        make -C ${PROJECT_ROOT_PATH}/ggml/src/ggml-hexagon/kernels/ clean
        make -C ${PROJECT_ROOT_PATH}/ggml/src/ggml-hexagon/kernels/ HTP_ARCH_VERSION=${extra_ver} HEXAGON_SDK_PATH=${HEXAGON_SDK_PATH} HEXAGON_TOOLS_PATH=${HEXAGON_TOOLS_PATH} DEBUG_FLAG="${dsp_debug_flag}"
        /bin/cp -fv ${PROJECT_ROOT_PATH}/ggml/src/ggml-hexagon/kernels/libggmldsp-skel.so ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-${extra_ver}.so
    done
}


#build JZ's ggml-hexagon backend for performance comparison
function build_arm64
{
    build_idl

    #make AI Agent happy
    export CCACHE_DIR=${PROJECT_ROOT_PATH}/.ccache

    #ARMv8.7a+i8mm CPU tuning flags, moved here from CMakeLists.txt to keep it aligned with upstream master
    local arm_cpu_flags="-march=armv8.7a+fp16+dotprod+i8mm -fvectorize -ffp-model=fast -fno-finite-math-only -flto -D_GNU_SOURCE"

    cmake -H. -B${LOCAL_BUILD_DIR} -DCMAKE_BUILD_TYPE=Release -DGGML_OPENMP=OFF -DGGML_OPENCL=OFF -DGGML_CCACHE=ON -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=latest -DGGML_HEXAGON=ON -DLLAMA_CURL=OFF -DGGML_LLAMAFILE=ON -DGGML_HEXAGON_JZ=ON -DHEXAGON_SDK_ROOT=${HEXAGON_SDK_PATH} -DHEXAGON_TOOLS_ROOT=${HEXAGON_TOOLS_PATH} -DHTP_ARCH_VERSION=${HTP_ARCH_VERSION} -DCMAKE_C_FLAGS="${arm_cpu_flags}" -DCMAKE_CXX_FLAGS="${arm_cpu_flags}" -DCMAKE_VERBOSE_MAKEFILE:BOOL=${VERBOSE} -DGGML_USE_HEXAGON=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_APP=OFF -DLLAMA_BUILD_UI=OFF -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_OPENSSL=OFF
    cd ${LOCAL_BUILD_DIR}
    make -j${HOST_CPU_COUNTS}
    #cmake POST_BUILD now builds all 4 DSP skels (v73/v75/v79/v81) in one pass; no script-side extras needed
    #build_extra_dsp_skels
    #upload the new libggmldsp-skel.so on device side
    prepare_ggmldsp
    #push AP-side libs too: libggml-hexagon.so embeds the regenerated FastRPC stub
    #which MUST stay in sync with the DSP skel signature, otherwise FastRPC args
    #get misaligned (root cause of the 8gen3 garbled-output regression).
    update_ggml_libs
    commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-cpu.so
    if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
        commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so
        # backup for AB testing: JZ's AP-side libs + DSP skels
        # libggml-hexagon.so leaks different libc++ symbols between JZ/QCOM, so all
        # transitively-linked libs (libggml, libllama, libllama-common, *-impl) must
        # be swapped together to avoid symbol lookup failures at runtime
        mkdir -p ${PROJECT_ROOT_PATH}/out/ab-test
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so          ${PROJECT_ROOT_PATH}/out/ab-test/libggml-hexagon-jz.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml.so                  ${PROJECT_ROOT_PATH}/out/ab-test/libggml-jz.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama.so                 ${PROJECT_ROOT_PATH}/out/ab-test/libllama-jz.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-common.so          ${PROJECT_ROOT_PATH}/out/ab-test/libllama-common-jz.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-completion-impl.so ${PROJECT_ROOT_PATH}/out/ab-test/libllama-completion-impl-jz.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-bench-impl.so      ${PROJECT_ROOT_PATH}/out/ab-test/libllama-bench-impl-jz.so
        for skel in ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-v*.so; do
            [ -f "$skel" ] || continue
            /bin/cp -fv "$skel" ${PROJECT_ROOT_PATH}/out/ab-test/
        done
        # libggml-opencl.so is optional (GGML_OPENCL=OFF by default); back up if present
        if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-opencl.so ]; then
            /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml-opencl.so ${PROJECT_ROOT_PATH}/out/ab-test/libggml-opencl-jz.so
        fi
    fi
    show_pwd

    cd -
}


#build JZ's ggml-hexagon backend in debug mode
function build_arm64_debug
{
    build_idl

    #make AI Agent happy
    export CCACHE_DIR=${PROJECT_ROOT_PATH}/.ccache

    #ARMv8.7a+i8mm CPU tuning flags, moved here from CMakeLists.txt to keep it aligned with upstream master
    local arm_cpu_flags="-march=armv8.7a+fp16+dotprod+i8mm -fvectorize -ffp-model=fast -fno-finite-math-only -flto -D_GNU_SOURCE"

    cmake -H. -B${LOCAL_BUILD_DIR} -DCMAKE_BUILD_TYPE=Debug -DGGML_OPENMP=OFF -DGGML_OPENCL=OFF -DGGML_CCACHE=ON -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=latest -DGGML_HEXAGON=ON -DLLAMA_CURL=OFF -DGGML_LLAMAFILE=ON -DGGML_HEXAGON_JZ=ON -DHEXAGON_SDK_ROOT=${HEXAGON_SDK_PATH} -DHEXAGON_TOOLS_ROOT=${HEXAGON_TOOLS_PATH} -DHTP_ARCH_VERSION=${HTP_ARCH_VERSION} -DCMAKE_C_FLAGS="${arm_cpu_flags}" -DCMAKE_CXX_FLAGS="${arm_cpu_flags}" -DCMAKE_VERBOSE_MAKEFILE:BOOL=${VERBOSE} -DGGML_USE_HEXAGON=ON -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF -DLLAMA_BUILD_APP=OFF -DLLAMA_BUILD_UI=OFF -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_OPENSSL=OFF
    cd ${LOCAL_BUILD_DIR}
    make -j${HOST_CPU_COUNTS}
    #cmake POST_BUILD now builds all 4 DSP skels (v73/v75/v79/v81) in one pass; no script-side extras needed
    #build_extra_dsp_skels debug
    #upload the new libggmldsp-skel.so on device side
    prepare_ggmldsp
    #push AP-side libs too (keep stub/skel in sync, see build_arm64 for rationale)
    update_ggml_libs
    commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-cpu.so
    if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
        commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so
    fi
    show_pwd

    cd -
}

#build Qualcomm's ggml-hexagon backend for performance comparison
function build_arm64_qcom
{
    #make AI Agent happy
    export CCACHE_DIR=${PROJECT_ROOT_PATH}/.ccache_qcom

    rm -f ${LOCAL_BUILD_DIR}/.ab_test_runtime

    /bin/cp -fv ${PROJECT_ROOT_PATH}/docs/backend/snapdragon/CMakeUserPresets.json .

    cmake -H. -B${LOCAL_BUILD_DIR} -DCMAKE_BUILD_TYPE=Release -DGGML_OPENMP=OFF -DGGML_OPENCL=OFF -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=latest -DGGML_HEXAGON=ON -DLLAMA_CURL=OFF -DGGML_LLAMAFILE=ON -DHEXAGON_SDK_ROOT=${HEXAGON_SDK_PATH} -DHEXAGON_TOOLS_ROOT=${HEXAGON_TOOLS_PATH} --preset arm64-android-snapdragon-release -DCMAKE_VERBOSE_MAKEFILE:BOOL=${VERBOSE}
    cmake --build ${LOCAL_BUILD_DIR}
    #upload the new libggml-htps.so on device side
    prepare_ggmlhtp
    #push AP-side libs too: QCOM build also needs to sync runtime libs
    update_ggml_libs
    # backup for AB testing: QCOM's AP-side libs + DSP skels
    if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
        mkdir -p ${PROJECT_ROOT_PATH}/out/ab-test
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so          ${PROJECT_ROOT_PATH}/out/ab-test/libggml-hexagon-qcom.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml.so                  ${PROJECT_ROOT_PATH}/out/ab-test/libggml-qcom.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama.so                 ${PROJECT_ROOT_PATH}/out/ab-test/libllama-qcom.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-common.so          ${PROJECT_ROOT_PATH}/out/ab-test/libllama-common-qcom.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-completion-impl.so ${PROJECT_ROOT_PATH}/out/ab-test/libllama-completion-impl-qcom.so
        /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-bench-impl.so      ${PROJECT_ROOT_PATH}/out/ab-test/libllama-bench-impl-qcom.so
        for skel in ${LOCAL_BUILD_DIR}/ggml/src/ggml-hexagon/libggml-htp-v*.so; do
            [ -f "$skel" ] || continue
            /bin/cp -fv "$skel" ${PROJECT_ROOT_PATH}/out/ab-test/
        done
        # libggml-opencl.so is optional (GGML_OPENCL=OFF by default); back up if present
        if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-opencl.so ]; then
            /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml-opencl.so ${PROJECT_ROOT_PATH}/out/ab-test/libggml-opencl-qcom.so
        fi
    fi
    show_pwd

    /bin/rm -f CMakeUserPresets.json

    echo "run following command to see the performance of qualcomm's official ggml-hexagon backend"
    echo "./scripts/build-run-android.sh run_llamacli"
    echo "./scripts/build-run-android.sh run_llamabench"
}


#build Android CPU-only reference (no ggml-hexagon) for correctness check and troubleshooting trick issues
function build_armcpu()
{
    export CCACHE_DIR=${PROJECT_ROOT_PATH}/.ccache_cpu

    #ARMv8.7a+i8mm CPU tuning flags, moved here from CMakeLists.txt to keep it aligned with upstream master
    local arm_cpu_flags="-march=armv8.7a+fp16+dotprod+i8mm -fvectorize -ffp-model=fast -fno-finite-math-only -flto -D_GNU_SOURCE"

    cmake -H. -B${LOCAL_BUILD_DIR} -DCMAKE_BUILD_TYPE=Release -DGGML_OPENMP=OFF -DGGML_CCACHE=ON -DCMAKE_TOOLCHAIN_FILE=${ANDROID_NDK}/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=latest -DGGML_HEXAGON=OFF -DLLAMA_CURL=OFF -DGGML_LLAMAFILE=ON -DCMAKE_C_FLAGS="${arm_cpu_flags}" -DCMAKE_CXX_FLAGS="${arm_cpu_flags}" -DCMAKE_VERBOSE_MAKEFILE:BOOL=${VERBOSE}
    cd ${LOCAL_BUILD_DIR}
    # use cmake --build so it matches whatever generator the cache was configured with
    cmake --build ${LOCAL_BUILD_DIR} -j${HOST_CPU_COUNTS}
    #remove stale hexagon artifacts from previous hexagon builds to ensure CPU-only runtime
    rm -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so
    rm -f ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-*.so
    # also clear QCOM skels left in the source dir by a prior build_qcom, else
    # detect_build_type() falls back to them and misreports hexagon-qcom
    rm -f ${LOCAL_BUILD_DIR}/ggml/src/ggml-hexagon/libggml-htp-*.so
    # backup CPU-only AP libs for AB switching (symmetric with build/build_qcom)
    # note: do NOT use "-cpu" suffix - libggml-cpu.so is the CPU backend impl, a
    # different lib from libggml.so (the core). use "-cpuonly" to avoid collision.
    mkdir -p ${PROJECT_ROOT_PATH}/out/ab-test
    /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libggml.so                  ${PROJECT_ROOT_PATH}/out/ab-test/libggml-cpuonly.so
    /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama.so                 ${PROJECT_ROOT_PATH}/out/ab-test/libllama-cpuonly.so
    /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-common.so          ${PROJECT_ROOT_PATH}/out/ab-test/libllama-common-cpuonly.so
    /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-completion-impl.so ${PROJECT_ROOT_PATH}/out/ab-test/libllama-completion-impl-cpuonly.so
    /bin/cp -fv ${LOCAL_BUILD_DIR}/bin/libllama-bench-impl.so      ${PROJECT_ROOT_PATH}/out/ab-test/libllama-bench-impl-cpuonly.so
    show_pwd
}


function remove_temp_dir()
{
    if [ -d ${LOCAL_BUILD_DIR} ]; then
        echo "remove ${LOCAL_BUILD_DIR} directory"
        rm -rf ${LOCAL_BUILD_DIR}
    fi
}


function update_cfg()
{
    adb push ${PROJECT_ROOT_PATH}/scripts/ggml-hexagon.cfg ${REMOTE_PATH}/
}


function build_ggml_hexagon()
{
    show_pwd
    check_and_download_ndk
    check_and_download_opencl_sdk
    check_and_download_hexagon_sdk
    dump_vars
    remove_temp_dir
    rm -f ${LOCAL_BUILD_DIR}/.ab_test_runtime
    build_arm64
}


function build_ggml_hexagon_debug()
{
    show_pwd
    check_and_download_ndk
    check_and_download_opencl_sdk
    check_and_download_hexagon_sdk
    dump_vars
    remove_temp_dir
    build_arm64_debug
}


function build_ggml_hexagon_qcom()
{
    show_pwd
    check_and_download_ndk
    check_and_download_opencl_sdk
    check_and_download_hexagon_sdk
    dump_vars
    remove_temp_dir
    build_arm64_qcom
}


#for Qualcomm's open-source ggml-hexagon backend in branch self-build-jz
function prepare_ggmlhtp()
{
    for ver in ${HTP_ARCH_VERSIONS}; do
        case "$ver" in
            v73 | v75 | v79 | v81)
                echo "adb push ${LOCAL_BUILD_DIR}/ggml/src/ggml-hexagon/libggml-htp-${ver}.so ${REMOTE_PATH}/libggml-htp-${ver}.so"
                adb push ${LOCAL_BUILD_DIR}/ggml/src/ggml-hexagon/libggml-htp-${ver}.so ${REMOTE_PATH}/libggml-htp-${ver}.so
            ;;
            *)
                show_usage
                exit 1
            ;;
        esac
    done
}


#for JZ's open-source ggml-hexagon backend in branch self-build-jz
function prepare_ggmldsp()
{
    adb push ${PROJECT_ROOT_PATH}/scripts/ggml-hexagon.cfg ${REMOTE_PATH}/ggml-hexagon.cfg
    for ver in ${HTP_ARCH_VERSIONS}; do
        if [ -f ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-${ver}.so ]; then
            echo "adb push ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-${ver}.so ${REMOTE_PATH}/libggmldsp-skel-${ver}.so"
            adb push ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-${ver}.so ${REMOTE_PATH}/libggmldsp-skel-${ver}.so
        fi
    done
}


function check_and_download_model()
{
    set +e

    model_name=$1
    model_url=$2

    adb shell ls /sdcard/${model_name}
    if [ $? -eq 0 ]; then
        printf "the prebuild LLM model ${model_name} already exist on Android phone\n"
    else
        printf "the prebuild LLM model ${model_name} not exist on Android phone\n"
        printf "downloading from ${model_url}\n"
        wget --no-config --quiet --show-progress -O ${PROJECT_ROOT_PATH}/models/${model_name} ${model_url}
        adb push ${PROJECT_ROOT_PATH}/models/${model_name} /sdcard/
    fi

    set -e
}


function check_prebuilt_models()
{
    set +e

    #1.12 GiB
    check_and_download_model qwen1_5-1_8b-chat-q4_0.gguf  https://huggingface.co/Qwen/Qwen1.5-1.8B-Chat-GGUF/resolve/main/qwen1_5-1_8b-chat-q4_0.gguf

    #1.2 GiB
    check_and_download_model Qwen3.5-2B-Q4_0.gguf         https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_0.gguf

    #2.58 GiB
    check_and_download_model Qwen3.5-4B-Q4_0.gguf         https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_0.gguf

    #5.1 GiB
    check_and_download_model Qwen3.5-9B-Q4_0.gguf         https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_0.gguf

    #2.9 GiB
    check_and_download_model gemma-4-E2B-it-Q4_0.gguf     https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_0.gguf

    # gemma-4-E4B_q4_0-it.gguf (4.9 GiB) is a stress-test model that triggers mirror/eviction in the 4GB ION mempool.
    check_and_download_model gemma-4-E4B_q4_0-it.gguf     https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf

    #737 MiB
    check_and_download_model Llama-3.2-1B-Instruct-Q4_0.gguf     https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_0.gguf

    set -e
}


# ==============================================================================
# Return codes:
#    0 = NO changes
#    1 = FILE CHANGED
# ==============================================================================
function is_so_file_changed() {
    set +e
    local so_file="$1"
    local md5_file="${so_file}.md5"

    # check if .so exists
    if [ ! -f "$so_file" ]; then
        echo "ERROR: File not found: $so_file"
        return 1
    fi

    # get current MD5
    local current_md5
    current_md5=$(md5sum "$so_file" | awk '{print $1}')

    # FIRST RUN: no MD5 file -> save it, return CHANGED
    if [ ! -f "$md5_file" ]; then
        echo "$current_md5" > "$md5_file"
        echo "Initialized MD5 for $so_file"
        return 1
    fi

    # read previous MD5
    local last_md5
    last_md5=$(cat "$md5_file")

    # compare
    if [ "$current_md5" = "$last_md5" ]; then
        # NO CHANGE
        return 0
    else
        # CHANGED -> update MD5
        echo "$current_md5" > "$md5_file"
        return 1
    fi
}

# Persist the current MD5 of a .so to its .md5 cache file. Call this ONLY after
# the file has been successfully pushed to the device.
function commit_so_file_md5() {
    local so_file="$1"
    local md5_file="${so_file}.md5"
    if [ -f "$so_file" ]; then
        md5sum "$so_file" | awk '{print $1}' > "$md5_file"
    fi
}


# Push AP-side libs (libggml-*.so, libllama-*.so) from bin/ to device.
# AP-only: does NOT push DSP skels (libggmldsp-skel-*.so / libggml-htp-*.so).
# Does NOT switch backend - DSP skels already on device stay as-is.
# Use update_jz_libs / update_qcom_libs for a full backend switch (AP + DSP).
# Gotcha: bin/ reflects the last build (JZ or QCOM); pushing JZ AP libs while
# QCOM DSP skels are still on device leaves an AP/DSP mismatch.
function update_ggml_libs()
{
    #adb push ${LOCAL_BUILD_DIR}/bin/*.so ${REMOTE_PATH}/
    adb push ${LOCAL_BUILD_DIR}/bin/libggml-base.so                 ${REMOTE_PATH}/
    adb push ${LOCAL_BUILD_DIR}/bin/libggml-cpu.so                  ${REMOTE_PATH}/
    #libggml-hexagon.so only exists in hexagon builds, not in CPU-only builds
    if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
        adb push ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so          ${REMOTE_PATH}/
    fi
    #libggml-opencl.so is optional (GGML_OPENCL=OFF by default)
    if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-opencl.so ]; then
        adb push ${LOCAL_BUILD_DIR}/bin/libggml-opencl.so          ${REMOTE_PATH}/
    fi
    adb push ${LOCAL_BUILD_DIR}/bin/libggml.so                      ${REMOTE_PATH}/
    adb push ${LOCAL_BUILD_DIR}/bin/libllama-common.so              ${REMOTE_PATH}/
    adb push ${LOCAL_BUILD_DIR}/bin/libllama-completion-impl.so     ${REMOTE_PATH}/
    adb push ${LOCAL_BUILD_DIR}/bin/libllama-bench-impl.so          ${REMOTE_PATH}/
    adb push ${LOCAL_BUILD_DIR}/bin/libllama.so                     ${REMOTE_PATH}/
}


#push JZ runtime .so from out/ab-test/ to device, renaming *-jz.so to canonical names
function update_jz_libs()
{
    local ab_test_dir=${PROJECT_ROOT_PATH}/out/ab-test
    if [ ! -f ${ab_test_dir}/libggml-hexagon-jz.so ]; then
        echo "ERROR: ${ab_test_dir}/libggml-hexagon-jz.so not found."
        echo "Run '$0 build' first to populate AB test backups."
        exit 1
    fi
    adb push ${ab_test_dir}/libggml-hexagon-jz.so          ${REMOTE_PATH}/libggml-hexagon.so
    adb push ${ab_test_dir}/libggml-jz.so                  ${REMOTE_PATH}/libggml.so
    adb push ${ab_test_dir}/libllama-jz.so                 ${REMOTE_PATH}/libllama.so
    adb push ${ab_test_dir}/libllama-common-jz.so          ${REMOTE_PATH}/libllama-common.so
    adb push ${ab_test_dir}/libllama-completion-impl-jz.so ${REMOTE_PATH}/libllama-completion-impl.so
    adb push ${ab_test_dir}/libllama-bench-impl-jz.so      ${REMOTE_PATH}/libllama-bench-impl.so
    for skel in ${ab_test_dir}/libggmldsp-skel-*.so; do
        [ -f "$skel" ] && adb push "$skel" ${REMOTE_PATH}/
    done
    # libggml-opencl.so is optional (GGML_OPENCL=OFF by default)
    if [ -f ${ab_test_dir}/libggml-opencl-jz.so ]; then
        adb push ${ab_test_dir}/libggml-opencl-jz.so ${REMOTE_PATH}/libggml-opencl.so
    else
        adb shell "rm -f ${REMOTE_PATH}/libggml-opencl.so"
    fi
    adb shell "rm -f ${REMOTE_PATH}/libggml-htp-*.so"
    echo "jz" > ${LOCAL_BUILD_DIR}/.ab_test_runtime
    echo "JZ runtime .so pushed to device."
}


#push QCOM runtime .so from out/ab-test/ to device, renaming *-qcom.so to canonical names
function update_qcom_libs()
{
    local ab_test_dir=${PROJECT_ROOT_PATH}/out/ab-test
    if [ ! -f ${ab_test_dir}/libggml-hexagon-qcom.so ]; then
        echo "ERROR: ${ab_test_dir}/libggml-hexagon-qcom.so not found."
        echo "Run '$0 build_qcom' first to populate AB test backups."
        exit 1
    fi
    adb push ${ab_test_dir}/libggml-hexagon-qcom.so          ${REMOTE_PATH}/libggml-hexagon.so
    adb push ${ab_test_dir}/libggml-qcom.so                  ${REMOTE_PATH}/libggml.so
    adb push ${ab_test_dir}/libllama-qcom.so                 ${REMOTE_PATH}/libllama.so
    adb push ${ab_test_dir}/libllama-common-qcom.so          ${REMOTE_PATH}/libllama-common.so
    adb push ${ab_test_dir}/libllama-completion-impl-qcom.so ${REMOTE_PATH}/libllama-completion-impl.so
    adb push ${ab_test_dir}/libllama-bench-impl-qcom.so      ${REMOTE_PATH}/libllama-bench-impl.so
    for skel in ${ab_test_dir}/libggml-htp-*.so; do
        [ -f "$skel" ] && adb push "$skel" ${REMOTE_PATH}/
    done
    # libggml-opencl.so is optional (GGML_OPENCL=OFF by default)
    if [ -f ${ab_test_dir}/libggml-opencl-qcom.so ]; then
        adb push ${ab_test_dir}/libggml-opencl-qcom.so ${REMOTE_PATH}/libggml-opencl.so
    else
        adb shell "rm -f ${REMOTE_PATH}/libggml-opencl.so"
    fi
    adb shell "rm -f ${REMOTE_PATH}/libggmldsp-skel-*.so"
    echo "qcom" > ${LOCAL_BUILD_DIR}/.ab_test_runtime
    echo "QCOM runtime .so pushed to device."
}


#push CPU-only runtime .so from out/ab-test/ to device, renaming *-cpuonly.so to canonical names
function update_cpu_libs()
{
    local ab_test_dir=${PROJECT_ROOT_PATH}/out/ab-test
    if [ ! -f ${ab_test_dir}/libggml-cpuonly.so ]; then
        echo "ERROR: ${ab_test_dir}/libggml-cpuonly.so not found."
        echo "Run '$0 build_armcpu' first to populate AB test backups."
        exit 1
    fi
    adb push ${ab_test_dir}/libggml-cpuonly.so                  ${REMOTE_PATH}/libggml.so
    adb push ${ab_test_dir}/libllama-cpuonly.so                 ${REMOTE_PATH}/libllama.so
    adb push ${ab_test_dir}/libllama-common-cpuonly.so          ${REMOTE_PATH}/libllama-common.so
    adb push ${ab_test_dir}/libllama-completion-impl-cpuonly.so ${REMOTE_PATH}/libllama-completion-impl.so
    adb push ${ab_test_dir}/libllama-bench-impl-cpuonly.so      ${REMOTE_PATH}/libllama-bench-impl.so
    # libggml-base.so / libggml-cpu.so are shared across builds, device-side kept as-is
    # libggml-opencl.so is optional (GGML_OPENCL=OFF by default)
    adb shell "rm -f ${REMOTE_PATH}/libggml-opencl.so"
    adb shell "rm -f ${REMOTE_PATH}/libggml-hexagon.so"
    adb shell "rm -f ${REMOTE_PATH}/libggmldsp-skel-*.so"
    adb shell "rm -f ${REMOTE_PATH}/libggml-htp-*.so"
    echo "cpu" > ${LOCAL_BUILD_DIR}/.ab_test_runtime
    echo "CPU-only runtime .so pushed to device."
}


#detect build type from build output: hexagon-jz, hexagon-qcom, or cpu-only
function detect_build_type()
{
    if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
        if ls ${LOCAL_BUILD_DIR}/bin/libggmldsp-skel-*.so 1>/dev/null 2>&1; then
            echo "hexagon-jz"
        else
            echo "hexagon-qcom"
        fi
    elif ls ${LOCAL_BUILD_DIR}/ggml/src/ggml-hexagon/libggml-htp-*.so 1>/dev/null 2>&1; then
        echo "hexagon-qcom"
    else
        echo "cpu-only"
    fi
}


function prepare_run_on_phone()
{
    if [ $# != 1 ]; then
        print "invalid param"
        return
    fi
    program=$1

    update_cfg

    check_prebuilt_models

    # AB test mode: if update_jz_libs/update_qcom_libs/update_cpu_libs set the marker,
    # skip lib/skel push - user has manually set up the runtime.
    local ab_test_marker="${LOCAL_BUILD_DIR}/.ab_test_runtime"
    if [ -f "${ab_test_marker}" ]; then
        local ab_runtime=$(cat "${ab_test_marker}")
        printf "AB test mode active: runtime='%s' (skipping lib/skel push)\n\n" "${ab_runtime}"
        adb push ${LOCAL_BUILD_DIR}/bin/${program} ${REMOTE_PATH}/
        adb shell ls -l ${REMOTE_PATH}/libggml-*.so
        adb shell chmod +x ${REMOTE_PATH}/${program}
        adb shell "rm -f /data/local/tmp/${program}.farf"
        adb shell "touch /data/local/tmp/${program}.farf"
        adb shell "echo 0x1c > /data/local/tmp/${program}.farf"
        return
    fi

    local current_build_type
    current_build_type=$(detect_build_type)

    local last_build_type_file="${LOCAL_BUILD_DIR}/.last_deployed_build_type"
    local last_build_type=""
    if [ -f "${last_build_type_file}" ]; then
        last_build_type=$(cat "${last_build_type_file}")
    fi

    if [ "${current_build_type}" != "${last_build_type}" ]; then
        printf "build type changed: '%s' -> '%s', force update ggml libs\n\n" "${last_build_type}" "${current_build_type}"
        update_ggml_libs
        commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-cpu.so
        if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
            commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so
        fi
        echo "${current_build_type}" > "${last_build_type_file}"
    else
        local need_update=0
        is_so_file_changed ${LOCAL_BUILD_DIR}/bin/libggml-cpu.so
        if [ $? -eq 0 ]; then
            printf "${LOCAL_BUILD_DIR}/bin/libggml-cpu.so not changed\n"
            #reuse cached/uploaded ggml runtime libs on device side to avoid time-consuming task on host side
        else
            printf "${LOCAL_BUILD_DIR}/bin/libggml-cpu.so has changed or first check\n"
            need_update=1
        fi
        if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
            is_so_file_changed ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so
            if [ $? -ne 0 ]; then
                printf "${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so has changed or first check\n"
                need_update=1
            else
                printf "${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so not changed\n"
            fi
        fi
        if [ ${need_update} -eq 0 ]; then
            #host-side MD5 matches cache, but verify libs actually exist on device
            #(user may have wiped /data/local/tmp manually, leaving host-side MD5 cache stale)
            if ! adb shell ls ${REMOTE_PATH}/libggml-cpu.so >/dev/null 2>&1; then
                printf "device-side libggml-cpu.so missing (maybe /data/local/tmp was wiped), force update ggml libs\n\n"
                need_update=1
            fi
        fi
        if [ ${need_update} -eq 0 ]; then
            printf "reuse cached/uploaded ggml runtime libs on device side\n\n"
        else
            #upload ggml runtime libs to Android phone
            update_ggml_libs
            commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-cpu.so
            if [ -f ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so ]; then
                commit_so_file_md5 ${LOCAL_BUILD_DIR}/bin/libggml-hexagon.so
            fi
        fi
    fi

    #deploy/cleanup backend-specific libs per build type
    case "${current_build_type}" in
        hexagon-jz)
            prepare_ggmldsp
            adb shell rm -f ${REMOTE_PATH}/libggml-htp-*.so
            ;;
        hexagon-qcom)
            prepare_ggmlhtp
            adb shell rm -f ${REMOTE_PATH}/libggmldsp-skel-*.so
            ;;
        cpu-only)
            adb shell rm -f ${REMOTE_PATH}/libggml-hexagon.so
            adb shell rm -f ${REMOTE_PATH}/libggmldsp-skel-*.so
            adb shell rm -f ${REMOTE_PATH}/libggml-htp-*.so
            adb shell rm -f ${REMOTE_PATH}/libggml-opencl.so
            ;;
    esac

    adb push ${LOCAL_BUILD_DIR}/bin/${program} ${REMOTE_PATH}/

    adb shell ls -l ${REMOTE_PATH}/libggml-*.so

    adb shell chmod +x ${REMOTE_PATH}/${program}

    # configuration for cDSP's logcat
    # FARF bits: 0x01=LOW 0x02=MEDIUM 0x04=HIGH 0x08=ERROR 0x10=FATAL
    # 0x1f = ALL (default; chatty: HAP_compute_res logs ~6x per RPC, 26K+/test)
    # 0x1c = HIGH+ERROR+FATAL (drop LOW+MEDIUM verbose spam; keep diag)
    # 0x18 = ERROR+FATAL  (only errors)
    # 0x00 = silent
    adb shell "rm -f /data/local/tmp/${program}.farf"
    adb shell "touch /data/local/tmp/${program}.farf"
    adb shell "echo 0x1c > /data/local/tmp/${program}.farf"
    #observe cDSP's log with debug build:./scripts/build-run-android.sh build_debug
    #adb logcat  | grep -iE "CDSP0"
}


function run_llamacli()
{
    local model_name=""
    local model_path=""

    if [ $# -ge 1 ]; then
        model_name="$1"
        model_path=$(resolve_model_name "$model_name")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_name'. Valid aliases: qwen3-2b, qwen3-4b, qwen3-9b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            exit 1
        fi
    else
        model_path="${GGUF_MODEL_NAME}"
    fi

    prepare_run_on_phone llama-completion

    #GGML_HEXAGON_OPPOLL is only effective for Qualcomm's ggml-hexagon, doesn't apply to JZ's ggml-hexagon
    echo "adb shell \"cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && export GGML_HEXAGON_OPPOLL=1 \
               && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\""
    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && export GGML_HEXAGON_OPPOLL=1 \
               && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\""

}


function run_llamabench()
{
    prepare_run_on_phone llama-bench

    #GGML_HEXAGON_OPPOLL is only effective for Qualcomm's ggml-hexagon, doesn't apply to JZ's ggml-hexagon
    echo "adb shell \"cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && export GGML_HEXAGON_OPPOLL=1 \
               && ${REMOTE_PATH}/llama-bench -t 6 --poll 1000 -ngl 99 -fa 1 --ubatch-size 1024 -p 200,500,800,1024 -n 128 -m ${GGUF_MODEL_NAME}\""

    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && export GGML_HEXAGON_OPPOLL=1 \
               && ${REMOTE_PATH}/llama-bench -t 6 --poll 1000 -ngl 99 -fa 1 --ubatch-size 1024 -p 200,500,800,1024 -n 128 -m ${GGUF_MODEL_NAME}"
}


function run_llamacli_all()
{
    local models=("gemma4-e2b" "qwen3-2b" "qwen3-4b" "qwen3-9b" "qwen1" "llama3" "gemma4-e4b")

    local total=${#models[@]}
    local count=0

    echo "=============================================="
    echo "  Batch inference test: ${#models[@]} models = ${total} tests"
    echo "=============================================="

    for model in "${models[@]}"; do
        count=$(( count + 1 ))
        echo ""
        echo "--- [${count}/${total}] model=${model} ---"
        run_llamacli "${model}"
    done

    echo ""
    echo "=============================================="
    echo "  Batch inference test complete: ${total} tests done"
    echo "=============================================="
}


# Long-prompt stress test (~5500 tokens) with gemma4-e4b (4.9 GiB) to fill KV cache,
# trigger mirror/eviction in the 4GB ION mempool, and exercise split/coalesce paths.
function run_stresstest()
{
    local prompt_file="${PROJECT_ROOT_PATH}/scripts/prompt_long_cinema.txt"
    local remote_prompt="/data/local/tmp/prompt_long.txt"
    local model_path="/sdcard/gemma-4-E4B_q4_0-it.gguf"

    if [ ! -f "${prompt_file}" ]; then
        echo "ERROR: prompt file not found: ${prompt_file}"
        exit 1
    fi

    prepare_run_on_phone llama-completion

    echo "--- Pushing long prompt (~5500 tokens) to device ---"
    adb push "${prompt_file}" "${remote_prompt}"

    echo "adb shell \"cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && export GGML_HEXAGON_OPPOLL=1 \
               && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -f ${remote_prompt}\""
    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && export GGML_HEXAGON_OPPOLL=1 \
               && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -f ${remote_prompt}"
}


function run_pp_only()
{
    # PP-only test: N llama-completion runs. We use -n 1 (not -n 0) because
    # -n 0 makes llama-completion exit right after load without processing
    # the prompt (batch_calls=0, no graph). With -n 1, we get exactly
    # 1 PP batch (the prompt) + 1 TG batch (1 generated token); the first
    # batch in OP-PROF log is "batch#1" = pure PP data, so we just grep
    # 'batch#1' in logcat.
    # With HEX_OP_PROF_DUMP_INTERVAL=1 in entry.c, every batch triggers
    # a dump, so one run is enough to capture the PP profile.
    # Usage: run_pp_only [model_alias] [round_count]
    #   model_alias: default gemma4-e2b-e2b (gemma-4-E2B-it-Q4_0.gguf)
    #   round_count: default 1 (more rounds only needed if data looks noisy)
    local model_name=""
    local model_path=""

    if [ $# -ge 1 ]; then
        model_name="$1"
        model_path=$(resolve_model_name "$model_name")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_name'. Valid aliases: qwen3-2b, qwen3-4b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            exit 1
        fi
    else
        model_path="${GGUF_MODEL_NAME}"
    fi

    prepare_run_on_phone llama-completion

    # -n 1: forces prompt processing (PP batch=1) + 1 TG step. The TG
    # step is harmless for PP analysis; the OP-PROF dump for 'batch#1'
    # contains exactly the PP graph.
    # --ubatch-size 1024: keeps the whole prompt in a single PP batch.
    local pp_params=" -ngl 99 -t 6 -n 1 --ctx-size 8192 --ubatch-size 1024 --poll 1000 --no-warmup --load-mode none -fa on --jinja -st"
    local round_count="${2:-1}"

    echo "=== PP-only test: ${round_count} round(s), model=${model_path} ==="
    for i in $(seq 1 ${round_count}); do
        echo "--- [${i}/${round_count}] ---"
        adb shell "cd ${REMOTE_PATH} \
                   && export LD_LIBRARY_PATH=${REMOTE_PATH} \
                   && export GGML_HEXAGON_OPPOLL=1 \
                   && ${REMOTE_PATH}/llama-completion ${pp_params} -m ${model_path} -p \"${PROMPT_STRING}\""
    done
    echo "=== PP-only test complete: ${round_count} round(s) done ==="
    echo "=== To extract the PP profile only, run: ==="
    echo "===   adb logcat | grep --line-buffered 'OP-PROF.*batch#1 ' | tee log_pp_only_\$(date +%Y%m%d-%H%M%S).txt ==="
}


function run_abtest()
{
    # JZ vs QCOM performance comparison test.
    # Requires out/ab-test/ populated (run 'build' then 'build_qcom' first).
    # Usage: run_abtest [rounds] [model_alias]
    #   rounds:      default 3
    #   model_alias: default gemma4-e2b
    #
    # Example:
    #   $0 run_abtest
    #   $0 run_abtest 5
    #   $0 run_abtest 3 qwen3-2b
    #   $0 run_abtest 2>&1 | tee log_abtest_$(date +%Y%m%d-%H%M%S).txt

    local rounds=3
    local model_path="${GGUF_MODEL_NAME}"
    local ab_test_dir=${PROJECT_ROOT_PATH}/out/ab-test

    if [ $# -ge 1 ]; then
        rounds=$1
    fi
    if [ $# -ge 2 ]; then
        local model_alias="$2"
        model_path=$(resolve_model_name "$model_alias")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_alias'. Valid aliases: qwen3-2b, qwen3-4b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            exit 1
        fi
    fi

    # sanity check: verify out/ab-test/ has all required .so from both builds
    local missing=""
    local jz_libs="libggml-hexagon-jz.so libggml-jz.so libllama-jz.so libllama-common-jz.so libllama-completion-impl-jz.so libllama-bench-impl-jz.so"
    local qcom_libs="libggml-hexagon-qcom.so libggml-qcom.so libllama-qcom.so libllama-common-qcom.so libllama-completion-impl-qcom.so libllama-bench-impl-qcom.so"
    for f in ${jz_libs}; do
        [ ! -f ${ab_test_dir}/${f} ] && missing="${missing} ${f}"
    done
    for f in ${qcom_libs}; do
        [ ! -f ${ab_test_dir}/${f} ] && missing="${missing} ${f}"
    done
    if [ -n "${missing}" ]; then
        echo "ERROR: AB test backups incomplete, missing:${missing}"
        echo ""
        echo "Run these two commands first to populate ${ab_test_dir}:"
        echo "  $0 build        # builds JZ ggml-hexagon, backs up *-jz.so"
        echo "  $0 build_qcom   # builds QCOM ggml-hexagon, backs up *-qcom.so"
        exit 1
    fi
    # check DSP skels exist for at least one HTP arch version
    local jz_skels=$(ls ${ab_test_dir}/libggmldsp-skel-*.so 2>/dev/null | wc -l)
    local qcom_skels=$(ls ${ab_test_dir}/libggml-htp-*.so 2>/dev/null | wc -l)
    if [ ${jz_skels} -eq 0 ] || [ ${qcom_skels} -eq 0 ]; then
        echo "ERROR: DSP skels missing in ${ab_test_dir}"
        echo "  JZ skels (libggmldsp-skel-*.so): ${jz_skels} found"
        echo "  QCOM skels (libggml-htp-*.so): ${qcom_skels} found"
        echo ""
        echo "Run these two commands first:"
        echo "  $0 build        # builds JZ DSP skels"
        echo "  $0 build_qcom   # builds QCOM DSP skels"
        exit 1
    fi

    echo "=============================================="
    echo "  AB test: JZ vs QCOM, ${rounds} rounds each"
    echo "  model: ${model_path}"
    echo "  $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="

    # --- JZ phase ---
    echo ""
    echo "=== [$(date '+%H:%M:%S')] Switching to JZ ==="
    adb push ${ab_test_dir}/libggml-hexagon-jz.so           ${REMOTE_PATH}/libggml-hexagon.so
    adb push ${ab_test_dir}/libggml-jz.so                   ${REMOTE_PATH}/libggml.so
    adb push ${ab_test_dir}/libllama-jz.so                  ${REMOTE_PATH}/libllama.so
    adb push ${ab_test_dir}/libllama-common-jz.so           ${REMOTE_PATH}/libllama-common.so
    adb push ${ab_test_dir}/libllama-completion-impl-jz.so  ${REMOTE_PATH}/libllama-completion-impl.so
    adb push ${ab_test_dir}/libllama-bench-impl-jz.so       ${REMOTE_PATH}/libllama-bench-impl.so
    for skel in ${ab_test_dir}/libggmldsp-skel-*.so; do
        [ -f "$skel" ] && adb push "$skel" ${REMOTE_PATH}/
    done
    # libggml-opencl.so is optional (GGML_OPENCL=OFF by default)
    if [ -f ${ab_test_dir}/libggml-opencl-jz.so ]; then
        adb push ${ab_test_dir}/libggml-opencl-jz.so ${REMOTE_PATH}/libggml-opencl.so
    else
        adb shell "rm -f ${REMOTE_PATH}/libggml-opencl.so"
    fi
    adb shell "rm -f ${REMOTE_PATH}/libggml-htp-*.so"

    echo ""
    echo "========================================"
    echo "  JZ test (${rounds} runs)"
    echo "========================================"
    for i in $(seq 1 ${rounds}); do
        echo ""
        echo "-------- JZ run ${i}/${rounds} $(date '+%H:%M:%S') --------"
        adb shell "cd ${REMOTE_PATH} && export LD_LIBRARY_PATH=${REMOTE_PATH} && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\""
        echo "-------- JZ run ${i} END --------"
    done

    # --- QCOM phase ---
    echo ""
    echo "=== [$(date '+%H:%M:%S')] Switching to QCOM ==="
    adb push ${ab_test_dir}/libggml-hexagon-qcom.so          ${REMOTE_PATH}/libggml-hexagon.so
    adb push ${ab_test_dir}/libggml-qcom.so                  ${REMOTE_PATH}/libggml.so
    adb push ${ab_test_dir}/libllama-qcom.so                 ${REMOTE_PATH}/libllama.so
    adb push ${ab_test_dir}/libllama-common-qcom.so          ${REMOTE_PATH}/libllama-common.so
    adb push ${ab_test_dir}/libllama-completion-impl-qcom.so ${REMOTE_PATH}/libllama-completion-impl.so
    adb push ${ab_test_dir}/libllama-bench-impl-qcom.so      ${REMOTE_PATH}/libllama-bench-impl.so
    for skel in ${ab_test_dir}/libggml-htp-*.so; do
        [ -f "$skel" ] && adb push "$skel" ${REMOTE_PATH}/
    done
    # libggml-opencl.so is optional (GGML_OPENCL=OFF by default)
    if [ -f ${ab_test_dir}/libggml-opencl-qcom.so ]; then
        adb push ${ab_test_dir}/libggml-opencl-qcom.so ${REMOTE_PATH}/libggml-opencl.so
    else
        adb shell "rm -f ${REMOTE_PATH}/libggml-opencl.so"
    fi
    adb shell "rm -f ${REMOTE_PATH}/libggmldsp-skel-*.so"

    echo ""
    echo "========================================"
    echo "  QCOM test (${rounds} runs)"
    echo "========================================"
    for i in $(seq 1 ${rounds}); do
        echo ""
        echo "-------- QCOM run ${i}/${rounds} $(date '+%H:%M:%S') --------"
        adb shell "cd ${REMOTE_PATH} && export LD_LIBRARY_PATH=${REMOTE_PATH} && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\""
        echo "-------- QCOM run ${i} END --------"
    done

    echo ""
    echo "=============================================="
    echo "  AB test complete $(date '+%Y-%m-%d %H:%M:%S')"
    echo "=============================================="

    # Restore current build type libs after AB test.
    # AB test leaves QCOM libs on device (QCOM is the last phase).
    # Without this, subsequent run_llamabench would skip pushing
    # libggml-hexagon.so (MD5 matches local JZ build), leaving device
    # in a mixed state: QCOM AP lib + JZ DSP skels -> error 0x80000406.
    local restore_type=""
    local last_bt_file="${LOCAL_BUILD_DIR}/.last_deployed_build_type"
    if [ -f "${last_bt_file}" ]; then
        restore_type=$(cat "${last_bt_file}")
    fi
    if [ -z "${restore_type}" ]; then
        restore_type="hexagon-jz"
    fi
    echo ""
    echo "=== [$(date '+%H:%M:%S')] Restoring build type: ${restore_type} ==="
    case "${restore_type}" in
        hexagon-jz)
            update_jz_libs
            ;;
        hexagon-qcom)
            update_qcom_libs
            ;;
        cpu-only)
            update_cpu_libs
            ;;
    esac
}


function run_abtest_all()
{
    # Run AB test across all 6 supported models.
    # Usage: run_abtest_all [rounds]
    #   rounds: default 3
    #
    # Example:
    #   $0 run_abtest_all
    #   $0 run_abtest_all 5
    #   $0 run_abtest_all 2>&1 | tee log_abtest_all_$(date +%Y%m%d-%H%M%S).txt

    local rounds=3
    if [ $# -ge 1 ]; then
        rounds=$1
    fi

    local all_models="qwen3-2b qwen3-4b qwen3-9b gemma4-e2b gemma4-e4b qwen1 llama3"
    local total=6
    local idx=0

    for model_alias in ${all_models}; do
        idx=$((idx + 1))
        echo ""
        echo "##############################################"
        echo "  AB test ${idx}/${total}: ${model_alias}"
        echo "  $(date '+%Y-%m-%d %H:%M:%S')"
        echo "##############################################"
        run_abtest ${rounds} ${model_alias}
    done

    echo ""
    echo "##############################################"
    echo "  All AB tests complete $(date '+%Y-%m-%d %H:%M:%S')"
    echo "##############################################"
}


function run_force_opfusion_in_pp_all()
{
    # Automated 6-model force_opfusion_in_pp=0 baseline verification.
    # Captures two logs per model with unified naming:
    #   log_forceopfusioninpp_<model>_<ts>_terminal.txt  - llama-completion stdout (PP/TG tok/s)
    #   log_forceopfusioninpp_<model>_<ts>_logcat.txt    - adb logcat | grep OP-PROF/QKV/FFN
    # Usage:
    #   $0 run_force_opfusion_in_pp_all

    local models=("gemma4-e2b" "qwen3-2b" "qwen3-4b" "qwen1" "llama3" "gemma4-e4b")
    local total=${#models[@]}
    local count=0

    echo "=============================================="
    echo "  force_opfusion_in_pp=0 baseline: ${total} models"
    echo "=============================================="

    for model in "${models[@]}"; do
        count=$(( count + 1 ))
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local log_term="log_forceopfusioninpp_${model}_${timestamp}_terminal.txt"
        local log_lc="log_forceopfusioninpp_${model}_${timestamp}_logcat.txt"
        local model_path=$(resolve_model_name "${model}")

        echo ""
        echo "--- [${count}/${total}] model=${model}, logs: ${log_term}, ${log_lc} ---"

        # Clear device logcat buffer so this run starts from empty
        adb logcat -c

        # Start logcat capture in background for this model
        adb logcat | grep --line-buffered -iE '(OP-PROF.*batch#1 |QKV skip|FFN skip|mul_mat coverage|hmx eligibility)' \
            > "${log_lc}" &
        sleep 1

        # Run inference, capture terminal output
        prepare_run_on_phone llama-completion
        adb shell "cd ${REMOTE_PATH} \
                   && export LD_LIBRARY_PATH=${REMOTE_PATH} \
                   && export GGML_HEXAGON_OPPOLL=1 \
                   && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\"" \
            2>&1 | tee "${log_term}"
    done

    # Final cleanup
    pkill -f "adb logcat" 2>/dev/null

    echo ""
    echo "=============================================="
    echo "  force_opfusion_in_pp=0 baseline complete: ${total} models done"
    echo "=============================================="
}


function run_ubatchtest()
{
    # Update ubatch-size values for a given model.
    # Usage: run_ubatchtest [model_alias] [ubatch_sizes_csv]
    #   model_alias    default: gemma4-e2b
    #   ubatch_sizes   default: 32,64,128,512,1024
    local model_alias="gemma4-e2b"
    local ubatch_sizes=(8 16 22 32 64 128 512 1024)
    local save_params="${running_params}"

    if [ $# -ge 1 ] && [ "$1" != "help" ] && [ "$1" != "-h" ]; then
        if [ -n "$(resolve_model_name "$1")" ]; then
            model_alias="$1"
        else
            echo "ERROR: unknown model alias '$1'. Valid: qwen3-2b, qwen3-4b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            return 1
        fi
    fi
    if [ $# -ge 2 ] && [ -n "$2" ]; then
        IFS=',' read -ra ubatch_sizes <<< "$2"
    fi

    local model_path=$(resolve_model_name "${model_alias}")
    [ -z "${model_path}" ] && { echo "ERROR: bad model"; return 1; }

    # ensure libs are on phone
    prepare_run_on_phone llama-completion

    local stamp=$(date +%Y%m%d-%H%M%S)
    local combined_log="ubatchtest_${model_alias}_${stamp}.log"

    echo "==================================================" | tee "${combined_log}"
    echo "  ubatch sweep: model=${model_alias}" | tee -a "${combined_log}"
    echo "  sizes: ${ubatch_sizes[*]}" | tee -a "${combined_log}"
    echo "  combined log: ${combined_log}" | tee -a "${combined_log}"
    echo "==================================================" | tee -a "${combined_log}"

    # per-ubatch metrics, accumulated in-memory
    declare -A pp_tps tg_tps tot_ms graphs unused_cnt
    local total=${#ubatch_sizes[@]}
    local count=0

    # temp file for parsing: stream via tee so user sees output in real-time,
    # then read the temp file after the stream ends to extract metrics
    local tmpf
    tmpf=$(mktemp /tmp/ubatchtest.XXXXXX.log)
    # shellcheck disable=SC2064
    trap "rm -f '${tmpf}'" RETURN

    # ---------- Phase 1: raw runs (stream to terminal + combined + temp) ----------
    # grep/awk in command substitutions may return non-zero on no-match;
    # with set -e + declare -A array assignment this would exit the script early
    set +e
    for ub in "${ubatch_sizes[@]}"; do
        count=$(( count + 1 ))
        echo "" | tee -a "${combined_log}"
        echo "--- [${count}/${total}] ubatch=${ub} ---" | tee -a "${combined_log}"

        # override --ubatch-size: strip old, append new
        local new_params
        new_params=$(echo "${save_params}" | sed -E 's/--ubatch-size[[:space:]]+[0-9]+//')
        new_params="${new_params} --ubatch-size ${ub}"
        running_params="${new_params}"

        # print the actual command for reproducibility (captured by tee)
        echo "CMD: cd ${REMOTE_PATH} && export LD_LIBRARY_PATH=${REMOTE_PATH} && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\"" | tee -a "${combined_log}"

        # stream adb output in real-time: terminal <- tmpf <- combined_log
        # First tee writes to tmpf (full capture for later parsing) and forwards to stdout.
        # Second tee appends to combined_log and forwards to stdout.
        # Both tees must keep their stdout -> terminal sees the stream live.
        # Do NOT redirect the second tee's stdout to /dev/null: that would
        # swallow the terminal stream (the bug we just fixed).
        adb shell "cd ${REMOTE_PATH} \
                  && export LD_LIBRARY_PATH=${REMOTE_PATH} \
                  && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \"${PROMPT_STRING}\"" 2>&1 \
            | tee "${tmpf}" \
            | tee -a "${combined_log}"

        # parse from temp file (after stream ends; full content available)
        # Anchor to "common_perf_print:" prefix to avoid matching model output
        pp_tps[$ub]=$(grep "common_perf_print:.*prompt eval time" "${tmpf}" | tail -1 \
            | grep -oE '[0-9.]+ tokens per second' | head -1 | awk '{print $1}')
        tg_tps[$ub]=$(grep "common_perf_print:.*eval time" "${tmpf}" | grep "runs" | tail -1 \
            | grep -oE '[0-9.]+ tokens per second' | head -1 | awk '{print $1}')
        tot_ms[$ub]=$(grep "common_perf_print:.*total time" "${tmpf}" | tail -1 \
            | sed -E 's/.*=\s*([0-9.]+) ms.*/\1/')
        unused_cnt[$ub]=$(grep -c '<unused' "${tmpf}")
        # line format: "...I common_perf_print:    graphs reused =        253"
        # field 5="reused", field 6="=", field 7="253" -> want $(i+2)
        graphs[$ub]=$(awk '/common_perf_print:.*graphs reused/ { for (i=1; i<=NF; i++) if ($i == "reused") { print $(i+2); exit } }' "${tmpf}")

        # truncate temp for next iteration (so grep on next ubatch is clean)
        : > "${tmpf}"
    done
    set -e

    # trap will clean up tmpf on function return
    running_params="${save_params}"

    # ---------- Phase 2: print summary from in-memory arrays ----------
    echo "" | tee -a "${combined_log}"
    echo "==================================================" | tee -a "${combined_log}"
    echo "  SUMMARY (parsed in-place during phase 1)" | tee -a "${combined_log}"
    echo "==================================================" | tee -a "${combined_log}"
    printf "%-7s  %-8s  %-8s  %-10s  %-7s  %-7s\n" \
        "ubatch" "PP_tps" "TG_tps" "total_ms" "unused" "graphs" | tee -a "${combined_log}"

    for ub in "${ubatch_sizes[@]}"; do
        printf "%-7s  %-8s  %-8s  %-10s  %-7s  %-7s\n" \
            "${ub}" "${pp_tps[$ub]:-N/A}" "${tg_tps[$ub]:-N/A}" "${tot_ms[$ub]:-N/A}" \
            "${unused_cnt[$ub]:-0}" "${graphs[$ub]:-N/A}" | tee -a "${combined_log}"
    done

    echo "==================================================" | tee -a "${combined_log}"
    echo "  done. combined log: ${combined_log}" | tee -a "${combined_log}"
    echo "==================================================" | tee -a "${combined_log}"
}


function run_ubatchtest_all()
{
    # Batch ubatch sweep across 6 models x 5 ubatches = 30 tests.
    # No arguments. Similar in spirit to run_llamacli_all.
    local models=("gemma4-e2b" "qwen3-2b" "qwen3-4b" "qwen1" "llama3" "gemma4-e4b")
    local ubatch_sizes=(32 64 128 512 1024)

    # re-join ubatch sizes back into a comma-separated string for run_ubatchtest
    local ubatch_csv
    ubatch_csv=$(IFS=,; echo "${ubatch_sizes[*]}")

    local total_models=${#models[@]}
    local total_ubatches=${#ubatch_sizes[@]}
    local total_tests=$(( total_models * total_ubatches ))
    local count=0

    echo "=============================================="
    echo "  Batch ubatch sweep:"
    echo "    ${total_models} models x ${total_ubatches} ubatches = ${total_tests} tests"
    echo "    models:    ${models[*]}"
    echo "    ubatches:  ${ubatch_sizes[*]}"
    echo "  Log capture example:"
    echo "    $0 run_ubatchtest_all 2>&1 | tee log_ci_\$(date +%Y%m%d-%H%M%S).txt"
    echo "=============================================="

    for model in "${models[@]}"; do
        count=$(( count + 1 ))
        echo ""
        echo "=== [${count}/${total_models}] model=${model} ==="
        run_ubatchtest "${model}" "${ubatch_csv}"
    done

    echo ""
    echo "=============================================="
    echo "  Batch ubatch sweep complete: ${total_tests} tests done"
    echo "=============================================="
}


function run_threadsafety()
{
    prepare_run_on_phone test-thread-safety

    echo "${REMOTE_PATH}/test-thread-safety -np 2 -m ${GGUF_MODEL_NAME} -p \"hello,world\" -n 256 -ngl 99 "
    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/test-thread-safety -np 1 -m ${GGUF_MODEL_NAME} -p \"hello,world\" -n 256 -ngl 99 "

}


function run_test-ops()
{
    prog_name=test-backend-ops
    prepare_run_on_phone ${prog_name}

    echo "adb shell \"cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/${prog_name} test\""


    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/${prog_name} test"

}


function run_test-op()
{
    prog_name=test-backend-ops
    prog_param="-o ${opname}"
    prepare_run_on_phone ${prog_name}

    echo "adb shell cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/${prog_name} test ${prog_param}"

    echo "\n"
    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/${prog_name} test ${prog_param}"

}


function run_perf-op()
{
    prog_name=test-backend-ops
    prepare_run_on_phone ${prog_name}

    echo "adb shell cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/${prog_name} perf -o ${opname}"

    echo "\n"
    adb shell "cd ${REMOTE_PATH} \
               && export LD_LIBRARY_PATH=${REMOTE_PATH} \
               && ${REMOTE_PATH}/${prog_name} perf -o ${opname}"

}


# 5.8.4-F: qwen1 TG root cause profiling.
# Runs qwen1 (24L, MHA 1:1) and gemma4-e2b (35L, GQA 8:1) TG with HEX_OP_PROF=1
# (every batch dumped). Validates three hypotheses for qwen1's TG loss
# (-28.8% vs QCOM, only TG loss in 6-model set):
#   H1 FLASH_ATTN: MHA KV reads 8x GQA, dominant if MHA-specific
#   H2 lm-head:   Q6_K->Q4_0 repack matvec bandwidth sub-expected
#   H3 KV inval:  per-token invalidation overhead on MHA's larger K/V
# Reference for comparison: §3.6 gemma4-e2b TG profile.
# Per-model logs are kept separate so the per-op comparison table is clean.
function run_qwen1_tg_prof()
{
    # ensure libs are on phone
    prepare_run_on_phone llama-completion

    # ensure latest cfg (enable_async_bulk_flush, etc.) is on the phone
    update_cfg

    local stamp=$(date +%Y%m%d-%H%M%S)
    local base="qwen1_tg_prof_${stamp}"
    local summary_log="${base}_summary.log"
    local qwen1_log="${base}_qwen1.log"
    local gemma4_log="${base}_gemma4.log"

    # Force M=1 for both PP and TG so profile is pure single-token.
    # (default --ubatch-size 64 mixes 1 PP batch + 256 TG batches;
    #  ubatch=1 makes the entire run M=1, eliminating PP contamination.)
    # -no-cnv: disable conversation mode. With -st + --jinja + user prompt,
    #   llama-completion emits "User-specified prompt will pre-start conversation"
    #   and the chat model immediately outputs [end of text] after 1 token,
    #   truncating TG to 1 step. We don't need chat semantics for perf testing.
    # Note: must be -no-cnv (single dash), not --no-cnv; see common/arg.cpp:1835.
    local save_params="${running_params}"
    running_params=" -ngl 99 -t 6 -n 256 --ctx-size 8192 --ubatch-size 1 --batch-size 1 --poll 1000 --no-warmup --load-mode none -fa on --jinja -no-cnv -st"

    # ---------------------------------------------------------------------
    # Header
    # ---------------------------------------------------------------------
    {
        echo "=========================================="
        echo "  5.8.4-F: qwen1 TG root cause profiling"
        echo "  Date: ${stamp}"
        echo "  Settings: M=1 (ubatch=1, batch=1), n_predict=256, ctx=8192"
        echo "  HEX_OP_PROF=1, HEX_OP_PROF_DUMP_INTERVAL=1 (per-batch dump)"
        echo "  Hypotheses: H1 FLASH_ATTN (MHA 1:1, KV 8x GQA),"
        echo "              H2 lm-head matvec bandwidth,"
        echo "              H3 per-token KV invalidation"
        echo "  Per-model logs:"
        echo "    ${qwen1_log}"
        echo "    ${gemma4_log}"
        echo "  This summary: ${summary_log}"
        echo "=========================================="
    } | tee "${summary_log}"

    # ---------------------------------------------------------------------
    # Run both models. MHA qwen1 = test, GQA gemma4-e2b = reference (§3.6).
    # Each model writes to its own log so OP-PROF extraction is per-model.
    # OP-PROF lines come from DSP via FARF -> logcat.
    # We use adb logcat -d (one-shot dump) AFTER each run, not background
    # streaming, to avoid the kill/wait hang trap on pipeline PID reaping.
    # OP-PROF is cumulative; the final dump contains full data.
    # ---------------------------------------------------------------------
    for model in qwen1 gemma4-e2b; do
        local model_path=$(resolve_model_name "${model}")
        [ -z "${model_path}" ] && { echo "ERROR: bad model ${model}"; running_params="${save_params}"; return 1; }
        local model_log="${base}_${model}.log"
        local model_logcat="${base}_${model}_logcat.log"

        {
            echo "=========================================="
            echo "  Model: ${model} (${model_path})"
            echo "  CMD: adb shell \"cd ${REMOTE_PATH} && export LD_LIBRARY_PATH=${REMOTE_PATH} && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \\\"${PROMPT_STRING}\\\"\""
            echo "  Logcat dump: ${model_logcat}"
            echo "=========================================="
        } | tee "${model_log}"

        # Clear logcat ring buffer so the post-run dump only sees this run.
        adb logcat -c 2>/dev/null || true

        # Run inference on phone (synchronous, blocks until completion).
        adb shell "cd ${REMOTE_PATH} \
                  && export LD_LIBRARY_PATH=${REMOTE_PATH} \
                  && ${REMOTE_PATH}/llama-completion ${running_params} \
                       -m ${model_path} \
                       -p \"${PROMPT_STRING}\"" 2>&1 \
            | tee -a "${model_log}"

        # One-shot dump the entire logcat ring buffer. Filter to OP-PROF lines.
        # Use '|| true' to avoid set -e abort on adb logcat -d transient errors.
        adb logcat -d 2>/dev/null \
            | grep -iE '(OP-PROF|OP-PROF-NONOP|OP-PROF-LAYER)' \
            > "${model_logcat}" || true
    done

    running_params="${save_params}"

    # ---------------------------------------------------------------------
    # Per-op profile extraction (per model, sorted by cum us desc).
    # OP-PROF format (entry.c dump_op_prof):
    #   [OP-PROF] <tag> op=<NAME> cum=<N> us count=<N> avg=<N> min=<N> max=<N> us
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  Per-op profile (cum us, descending, top 20)"
        echo "=========================================="
    } | tee -a "${summary_log}"

    for model in qwen1 gemma4-e2b; do
        local model_logcat="${base}_${model}_logcat.log"
        {
            echo ""
            echo "--- ${model} per-op profile (cum us, descending) ---"
            # Reformat: prepend cum value, sort numerically desc, strip cum column.
            grep "OP-PROF" "${model_logcat}" \
                | grep -oE 'op=[A-Z_0-9]+ cum=[0-9]+ us count=[0-9]+ avg=[0-9]+ min=[0-9]+ max=[0-9]+' \
                | sed -E 's/.* cum=([0-9]+) us.*/\1 &/' \
                | sort -k1 -n -r \
                | sed -E 's/^[0-9]+ //' \
                | head -20
        } | tee -a "${summary_log}"
    done

    # ---------------------------------------------------------------------
    # Per-batch non-op overhead (hdr, pre, w-inv, a-inv, dst, bulk, queue).
    # Dumped on the same cadence as OP-PROF (HEX_OP_PROF_DUMP_INTERVAL=1).
    # Average the last 5 dumps for stability (initial DSP warmup is noisy).
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  Per-batch non-op overhead (us/batch, last 5 dumps)"
        echo "=========================================="
    } | tee -a "${summary_log}"

    for model in qwen1 gemma4-e2b; do
        local model_logcat="${base}_${model}_logcat.log"
        {
            echo ""
            echo "--- ${model} per-batch non-op overhead (last 5 dumps) ---"
            # OP-PROF-NONOP: hdr=NNN pre=NNN w-inv=NNN(NMB) a-inv=NNN(NMB) dst=NNN bulk=NNN queue=NNN
            grep "OP-PROF-NONOP" "${model_logcat}" \
                | grep -oE 'hdr=[0-9]+ pre=[0-9]+ w-inv=[0-9]+\([0-9]+MB\) a-inv=[0-9]+\([0-9]+MB\) dst=[0-9]+ bulk=[0-9]+ queue=[0-9]+' \
                | tail -5
        } | tee -a "${summary_log}"
    done

    # ---------------------------------------------------------------------
    # dump_perf_stats summary (cumulative p10, civac, etc.) for cross-ref.
    # We grep both model logs and concatenate, tagged by model.
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  dump_perf_stats summary (per model)"
        echo "=========================================="
    } | tee -a "${summary_log}"

    for model in qwen1 gemma4-e2b; do
        local model_log="${base}_${model}.log"
        {
            echo ""
            echo "--- ${model} dump_perf_stats ---"
            awk '/ggmlhexagon_dump_perf_stats/ {flag=1; print; next}
                 /^---/ {flag=0}
                 flag {print}' "${model_log}"
        } | tee -a "${summary_log}"
    done

    {
        echo ""
        echo "=========================================="
        echo "  Done."
        echo "  Share these 5 files for analysis:"
        echo "    ${summary_log}      (per-op comparison + non-op overhead + dump_perf_stats)"
        echo "    ${qwen1_log}        (qwen1 terminal output)"
        echo "    ${gemma4_log}       (gemma4 terminal output)"
        echo "    ${base}_qwen1_logcat.log  (qwen1 raw OP-PROF stream from DSP)"
        echo "    ${base}_gemma4_logcat.log (gemma4 raw OP-PROF stream from DSP)"
        echo "  Next: per-op comparison for H1 (FLASH_ATTN), H2 (lm-head), H3 (KV inval)."
        echo "=========================================="
    } | tee -a "${summary_log}"
}

function run_qwen3_9b_tg_prof()
{
    # ensure libs are on phone
    prepare_run_on_phone llama-completion

    # ensure latest cfg (enable_async_bulk_flush, etc.) is on the phone
    update_cfg

    local stamp=$(date +%Y%m%d-%H%M%S)
    local base="qwen3_9b_tg_prof_${stamp}"
    local summary_log="${base}_summary.log"
    local qwen3_9b_log="${base}_qwen3-9b.log"
    local gemma4_log="${base}_gemma4-e2b.log"

    # Force M=1 for both PP and TG so profile is pure single-token.
    # (default --ubatch-size 64 mixes 1 PP batch + 256 TG batches;
    #  ubatch=1 makes the entire run M=1, eliminating PP contamination.)
    # -no-cnv: disable conversation mode. With -st + --jinja + user prompt,
    #   llama-completion emits "User-specified prompt will pre-start conversation"
    #   and the chat model immediately outputs [end of text] after 1 token,
    #   truncating TG to 1 step. We don't need chat semantics for perf testing.
    # Note: must be -no-cnv (single dash), not --no-cnv; see common/arg.cpp:1835.
    # 9B is GQA, not MHA, so this run compares GQA-vs-GQA (9B vs gemma4-e2b).
    # Use the same M=1 settings as run_qwen1_tg_prof for direct comparison.
    local save_params="${running_params}"
    running_params=" -ngl 99 -t 6 -n 256 --ctx-size 8192 --ubatch-size 1 --batch-size 1 --poll 1000 --no-warmup --load-mode none -fa on --jinja -no-cnv -st"

    # ---------------------------------------------------------------------
    # Header
    # ---------------------------------------------------------------------
    {
        echo "=========================================="
        echo "  5.8.5-F2: qwen3.5-9B TG 5x gap root cause profiling"
        echo "  Date: ${stamp}"
        echo "  Settings: M=1 (ubatch=1, batch=1), n_predict=256, ctx=8192"
        echo "  HEX_OP_PROF=1, HEX_OP_PROF_DUMP_INTERVAL=1 (per-batch dump)"
        echo "  Reference: QCOM PP=135 tok/s, TG=7 tok/s;"
        echo "             JZ current PP=23.9 tok/s, TG=1.32 tok/s (5x gap)"
        echo "  Hypotheses (9B-specific, GQA + 5x params vs qwen1):"
        echo "    H1 graph split (batch_calls >> 256 = missing op or frag)"
        echo "    H2 missing op (specific op not registered, slow fallback)"
        echo "    H3 a-inv explosion (5x more params = 5x more activation)"
        echo "  Per-model logs:"
        echo "    ${qwen3_9b_log}"
        echo "    ${gemma4_log}"
        echo "  This summary: ${summary_log}"
        echo "=========================================="
    } | tee "${summary_log}"

    # ---------------------------------------------------------------------
    # Run models. qwen3.5-9B = test (GQA 4:1, 40 layers, 9B params),
    # gemma4-e2b = GQA reference (GQA 8:1, 35 layers, 2B params).
    # Same DSP-side OP-PROF stream via logcat as run_qwen1_tg_prof.
    # 9B model size: 5.4 GB Q4_0, will stress mempool; mempool size
    # must be at least 6 GB on phone or run will fail at model load.
    # ---------------------------------------------------------------------
    for model in qwen3-9b gemma4-e2b; do
        local model_path=$(resolve_model_name "${model}")
        [ -z "${model_path}" ] && { echo "ERROR: bad model ${model}"; running_params="${save_params}"; return 1; }
        local model_log="${base}_${model}.log"
        local model_logcat="${base}_${model}_logcat.log"

        {
            echo "=========================================="
            echo "  Model: ${model} (${model_path})"
            echo "  CMD: adb shell \"cd ${REMOTE_PATH} && export LD_LIBRARY_PATH=${REMOTE_PATH} && ${REMOTE_PATH}/llama-completion ${running_params} -m ${model_path} -p \\\"${PROMPT_STRING}\\\"\""
            echo "  Logcat dump: ${model_logcat}"
            echo "=========================================="
        } | tee "${model_log}"

        # Clear logcat ring buffer so the post-run dump only sees this run.
        adb logcat -c 2>/dev/null || true

        # Run inference on phone (synchronous, blocks until completion).
        adb shell "cd ${REMOTE_PATH} \
                  && export LD_LIBRARY_PATH=${REMOTE_PATH} \
                  && ${REMOTE_PATH}/llama-completion ${running_params} \
                       -m ${model_path} \
                       -p \"${PROMPT_STRING}\"" 2>&1 \
            | tee -a "${model_log}"

        # One-shot dump the entire logcat ring buffer. Filter to OP-PROF lines.
        # Use '|| true' to avoid set -e abort on adb logcat -d transient errors.
        adb logcat -d 2>/dev/null \
            | grep -iE '(OP-PROF|OP-PROF-NONOP|OP-PROF-LAYER)' \
            > "${model_logcat}" || true
    done

    running_params="${save_params}"

    # ---------------------------------------------------------------------
    # Per-op profile extraction (per model, sorted by cum us desc).
    # OP-PROF format (entry.c dump_op_prof):
    #   [OP-PROF] <tag> op=<NAME> cum=<N> us count=<N> avg=<N> min=<N> max=<N> us
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  Per-op profile (cum us, descending, top 20)"
        echo "=========================================="
    } | tee -a "${summary_log}"

    for model in qwen3-9b gemma4-e2b; do
        local model_logcat="${base}_${model}_logcat.log"
        {
            echo ""
            echo "--- ${model} per-op profile (cum us, descending) ---"
            grep "OP-PROF" "${model_logcat}" \
                | grep -oE 'op=[A-Z_0-9]+ cum=[0-9]+ us count=[0-9]+ avg=[0-9]+ min=[0-9]+ max=[0-9]+' \
                | sed -E 's/.* cum=([0-9]+) us.*/\1 &/' \
                | sort -k1 -n -r \
                | sed -E 's/^[0-9]+ //' \
                | head -20
        } | tee -a "${summary_log}"
    done

    # ---------------------------------------------------------------------
    # Per-batch non-op overhead (hdr, pre, w-inv, a-inv, dst, bulk, queue).
    # Dumped on the same cadence as OP-PROF (HEX_OP_PROF_DUMP_INTERVAL=1).
    # Average the last 5 dumps for stability (initial DSP warmup is noisy).
    # For 9B, watch a-inv MB and bulk MB carefully: 5x more params vs qwen1
    # means activation footprint and dst flush cost both scale ~5x.
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  Per-batch non-op overhead (us/batch, last 5 dumps)"
        echo "=========================================="
    } | tee -a "${summary_log}"

    for model in qwen3-9b gemma4-e2b; do
        local model_logcat="${base}_${model}_logcat.log"
        {
            echo ""
            echo "--- ${model} per-batch non-op overhead (last 5 dumps) ---"
            grep "OP-PROF-NONOP" "${model_logcat}" \
                | grep -oE 'hdr=[0-9]+ pre=[0-9]+ w-inv=[0-9]+\([0-9]+MB\) a-inv=[0-9]+\([0-9]+MB\) dst=[0-9]+ bulk=[0-9]+ queue=[0-9]+' \
                | tail -5
        } | tee -a "${summary_log}"
    done

    # ---------------------------------------------------------------------
    # dump_perf_stats summary (cumulative p10, civac, etc.) for cross-ref.
    # Key signal: batch_calls. 256 = no graph split (good).
    # >1000 = still has missing-op splits (H1 confirmed).
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  dump_perf_stats summary (per model)"
        echo "=========================================="
    } | tee -a "${summary_log}"

    for model in qwen3-9b gemma4-e2b; do
        local model_log="${base}_${model}.log"
        {
            echo ""
            echo "--- ${model} dump_perf_stats ---"
            awk '/ggmlhexagon_dump_perf_stats/ {flag=1; print; next}
                 /^---/ {flag=0}
                 flag {print}' "${model_log}"
        } | tee -a "${summary_log}"
    done

    {
        echo ""
        echo "=========================================="
        echo "  Done."
        echo "  Share these 5 files for analysis:"
        echo "    ${summary_log}            (per-op comparison + non-op overhead + dump_perf_stats)"
        echo "    ${qwen3_9b_log}           (qwen3.5-9B terminal output)"
        echo "    ${gemma4_log}             (gemma4-e2b terminal output)"
        echo "    ${base}_qwen3-9b_logcat.log  (qwen3.5-9B raw OP-PROF stream from DSP)"
        echo "    ${base}_gemma4-e2b_logcat.log (gemma4-e2b raw OP-PROF stream from DSP)"
        echo "  Next: per-op comparison for H1 (graph split / missing op), H2 (a-inv),"
        echo "        H3 (lm-head / matvec bandwidth)."
        echo "  Compare with qwen1_tg_prof (Table-19/20/21/22) to estimate 5x gap origin."
        echo "=========================================="
    } | tee -a "${summary_log}"
}

# ============================================================
# run_qwen3_9b_only : 5.8.5-F2 9B cgraph dump (debug)
#
# Minimal run of qwen3.5-9B only. Skips gemma4-e2b and the perf-comparison
# summary. Purpose: capture all ~7450 CGRAPH-DUMP one-liners + 25 unique
# === GRAPH === blocks to a single logcat file, so we can identify which op
# causes the 25-way graph split. Prereq: [cdsp] dump_cgraph = 2 in
# scripts/ggml-hexagon.cfg. Output: qwen3_9b_cgraph_<ts>_logcat.log.
# ============================================================
function run_qwen3_9b_only()
{
    prepare_run_on_phone llama-completion
    update_cfg

    local stamp=$(date +%Y%m%d-%H%M%S)
    local base="qwen3_9b_cgraph_${stamp}"
    local log_file="${base}.log"
    local logcat_file="${base}_logcat.log"

    local save_params="${running_params}"
    # Same M=1 + n_predict=256 + ctx=8192 as run_qwen3_9b_tg_prof.
    running_params=" -ngl 99 -t 6 -n 256 --ctx-size 8192 --ubatch-size 1 --batch-size 1 --poll 1000 --no-warmup --load-mode none -fa on --jinja -no-cnv -st"

    local model="qwen3-9b"
    local model_path=$(resolve_model_name "${model}")
    if [ -z "${model_path}" ]; then
        echo "ERROR: unknown model alias '${model}'"
        running_params="${save_params}"
        return 1
    fi

    {
        echo "=========================================="
        echo "  5.8.5-F2: qwen3.5-9B cgraph dump (minimal)"
        echo "  Date: ${stamp}"
        echo "  Model: ${model} (${model_path})"
        echo "  Settings: M=1 (ubatch=1, batch=1), n_predict=256, ctx=8192"
        echo "  Req: scripts/ggml-hexagon.cfg has [cdsp] dump_cgraph = 2"
        echo "  Output:"
        echo "    ${log_file}      (qwen3-9B terminal output)"
        echo "    ${logcat_file}   (CGRAPH-DUMP one-liners + 25 unique === GRAPH === blocks)"
        echo "  Next: identify which op causes 25-way graph split; fix missing"
        echo "        AP validator (cf. 3.7 / 6.2 SOLVE_TRI / SSM_CONV pattern)."
        echo "=========================================="
    } | tee "${log_file}"

    # Clear logcat so the dump captures only this run.
    adb logcat -c 2>/dev/null || true

    # Run inference on phone (synchronous, blocks until completion).
    adb shell "cd ${REMOTE_PATH} \
              && export LD_LIBRARY_PATH=${REMOTE_PATH} \
              && ${REMOTE_PATH}/llama-completion ${running_params} \
                   -m ${model_path} \
                   -p \"${PROMPT_STRING}\"" 2>&1 \
        | tee -a "${log_file}"

    # One-shot dump the entire logcat ring buffer. Filter to CGRAPH-DUMP +
    # full === GRAPH === blocks.
    adb logcat -d 2>/dev/null \
        | grep -iE 'CGRAPH-DUMP|=== GRAPH|ggml_op' \
        | tee "${logcat_file}"

    {
        echo ""
        echo "=========================================="
        echo "  Done. ${logcat_file} captured."
        echo ""
        echo "  Quick analysis commands:"
        echo "    # 25 unique (first, last, n) triples (top 25):"
        echo "    grep CGRAPH-DUMP ${logcat_file} | grep -oE 'nodes=[0-9]+ first=[A-Z_]+ last=[A-Z_]+' | sort | uniq -c | sort -rn | head -25"
        echo ""
        echo "    # count cache misses (expect ~25 = unique shapes):"
        echo "    grep -c 'CGRAPH-DUMP.*MISS' ${logcat_file}"
        echo ""
        echo "    # count full cgraph dumps (expect 25):"
        echo "    grep -c '=== GRAPH' ${logcat_file}"
        echo "=========================================="
    } | tee -a "${log_file}"

    running_params="${save_params}"
}

# H1 + H2 verification: sweep ctx_size to compare MHA (qwen1) vs GQA
# (gemma4-e2b 8:1) on FLASH_ATTN and lm-head op costs.
#
# H1 (FLASH_ATTN): MHA reads 2*n_embd*2B = 8 KB per token per layer from K/V
# cache vs GQA 8:1's 1 KB. Expectation if H1 holds: qwen1 FLASH_ATTN avg
# grows ~8x faster with ctx than gemma4-e2b's.
#
# H2 (lm-head matvec): qwen1 lm-head = 151936 * 1536 * Q4_0 = 116 MB,
# gemma4-e2b lm-head ~ 196 MB. Effective DRAM bandwidth on 8 Elite = ~64 GB/s
# (LPDDR5x 5300 MT/s), so theoretical lm-head floor is ~1.8-3.1 ms/token.
# Compare actual vs theoretical; if actual << theoretical, kernel is
# bandwidth-bound and DSP-side DRAM prefetch could help.
function run_flash_lmhead_prof()
{
    prepare_run_on_phone llama-completion
    update_cfg

    local stamp=$(date +%Y%m%d-%H%M%S)
    local base="h1h2_prof_${stamp}"
    local summary_log="${base}_summary.log"
    # 3 ctx points: short (1K), mid (4K), long (16K) — enough to see linear
    # vs sublinear growth. 32K omitted (qwen1 K/V ~24*1KB*32K = 768MB would
    # pressure mempool, trigger mirrors, confound measurement).
    local ctxs="1024 4096 16384"
    local models="qwen1 gemma4-e2b"

    local save_params="${running_params}"
    # M=1 (ubatch=1, batch=1) for pure single-token TG profile, same as
    # run_qwen1_tg_prof. -no-cnv (single dash) avoids chat-mode truncation.
    running_params=" -ngl 99 -t 6 -n 256 --ubatch-size 1 --batch-size 1 --poll 1000 --no-warmup --load-mode none -fa on --jinja -no-cnv -st"

    {
        echo "=========================================="
        echo "  5.8.4-F: H1 (FLASH_ATTN) + H2 (lm-head) ctx sweep"
        echo "  Date: ${stamp}"
        echo "  Settings: M=1 (ubatch=1, batch=1), n_predict=256, ctx sweep: ${ctxs}"
        echo "  HEX_OP_PROF=1, HEX_OP_PROF_DUMP_INTERVAL=1 (per-batch dump)"
        echo "  Hypotheses:"
        echo "    H1: MHA 1:1 KV 8x GQA 8:1, FLASH_ATTN avg grows ~8x faster with ctx"
        echo "    H2: lm-head matvec actual DRAM bandwidth vs theoretical ~64 GB/s"
        echo "  Per-run files: ${base}_<model>_ctx<N>*.log (6 files + 6 logcat dumps)"
        echo "  This summary: ${summary_log}"
        echo "=========================================="
    } | tee "${summary_log}"

    # ---------------------------------------------------------------------
    # 6 runs: each (model, ctx) writes its own log + logcat dump. Same
    # adb logcat -d post-dump pattern as run_qwen1_tg_prof to avoid the
    # kill/wait hang trap on background pipeline PID reaping.
    # ---------------------------------------------------------------------
    for ctx in ${ctxs}; do
        for model in ${models}; do
            local model_path=$(resolve_model_name "${model}")
            [ -z "${model_path}" ] && { echo "ERROR: bad model ${model}"; running_params="${save_params}"; return 1; }
            local run_log="${base}_${model}_ctx${ctx}.log"
            local run_logcat="${base}_${model}_ctx${ctx}_logcat.log"

            {
                echo ""
                echo "=========================================="
                echo "  Run: ${model} ctx=${ctx}"
                echo "  Logcat dump: ${run_logcat}"
                echo "=========================================="
            } | tee -a "${summary_log}"

            adb logcat -c 2>/dev/null || true

            adb shell "cd ${REMOTE_PATH}                       && export LD_LIBRARY_PATH=${REMOTE_PATH}                       && ${REMOTE_PATH}/llama-completion ${running_params} --ctx-size ${ctx}                            -m ${model_path}                            -p \"${PROMPT_STRING}\"" 2>&1                 | tee "${run_log}"

            adb logcat -d 2>/dev/null                 | grep -iE '(OP-PROF|OP-PROF-NONOP|OP-PROF-LAYER)'                 > "${run_logcat}" || true
        done
    done

    running_params="${save_params}"

    # ---------------------------------------------------------------------
    # H1 extraction: FLASH_ATTN avg us per batch, per (model, ctx).
    # Op tag is FLASH_ATTN (entry.c HEX_OP_PROF dump for GGML_OP_FLASH_ATTN).
    # If tag differs, the grep falls back to a broad match and the avg
    # column is left blank (then ratio printed as "n/a").
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  H1: FLASH_ATTN avg us per batch (M=1 TG, varies with ctx)"
        echo "  Expected if H1 holds: qwen1 grows ~8x faster than gemma4"
        echo "=========================================="
        printf "  %-10s %-12s %-12s %-12s %-12s\n" "ctx" "qwen1 avg" "gemma4 avg" "qwen1/gemma4" "verdict"
        for ctx in ${ctxs}; do
            local q1_avg=$(grep "OP-PROF" "${base}_qwen1_ctx${ctx}_logcat.log"                           | grep -oE 'op=FLASH_ATTN[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                           | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
            local g4_avg=$(grep "OP-PROF" "${base}_gemma4_ctx${ctx}_logcat.log"                           | grep -oE 'op=FLASH_ATTN[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                           | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
            local ratio="n/a"
            local verdict="n/a"
            if [ -n "${q1_avg}" ] && [ -n "${g4_avg}" ] && [ "${g4_avg}" -gt 0 ]; then
                ratio=$(awk -v q="${q1_avg}" -v g="${g4_avg}" 'BEGIN { printf "%.2f", q/g }')
                # H1 verdict: qwen1 should be larger and grow faster
                verdict="qwen1_larger"
            fi
            printf "  %-10s %-12s %-12s %-12s %-12s\n" "${ctx}" "${q1_avg:-n/a}" "${g4_avg:-n/a}" "${ratio}" "${verdict}"
        done

        # H1 growth analysis: compare slope from ctx=1024 to ctx=16384
        echo ""
        echo "  H1 growth: ratio of (avg at ctx=16384) / (avg at ctx=1024)"
        echo "  Expected if H1 holds: qwen1 ratio >> gemma4 ratio (MHA linear, GQA sublinear)"
        local q1_first=$(grep "OP-PROF" "${base}_qwen1_ctx1024_logcat.log"                        | grep -oE 'op=FLASH_ATTN[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                        | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
        local q1_last=$(grep "OP-PROF" "${base}_qwen1_ctx16384_logcat.log"                       | grep -oE 'op=FLASH_ATTN[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                       | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
        local g4_first=$(grep "OP-PROF" "${base}_gemma4_ctx1024_logcat.log"                        | grep -oE 'op=FLASH_ATTN[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                        | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
        local g4_last=$(grep "OP-PROF" "${base}_gemma4_ctx16384_logcat.log"                       | grep -oE 'op=FLASH_ATTN[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                       | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
        if [ -n "${q1_first}" ] && [ -n "${q1_last}" ] && [ "${q1_first}" -gt 0 ]; then
            local q1_growth=$(awk -v a="${q1_first}" -v b="${q1_last}" 'BEGIN { printf "%.2f", b/a }')
            echo "    qwen1   growth: ${q1_growth}x  (1024->16384)"
        else
            echo "    qwen1   growth: n/a"
        fi
        if [ -n "${g4_first}" ] && [ -n "${g4_last}" ] && [ "${g4_first}" -gt 0 ]; then
            local g4_growth=$(awk -v a="${g4_first}" -v b="${g4_last}" 'BEGIN { printf "%.2f", b/a }')
            echo "    gemma4  growth: ${g4_growth}x  (1024->16384)"
        else
            echo "    gemma4  growth: n/a"
        fi
    } | tee -a "${summary_log}"

    # ---------------------------------------------------------------------
    # H2 extraction: lm-head op (last layer matvec to vocab). Op tag is
    # MUL_MAT with the weight being the embedding/lm_head matrix. We
    # grep broadly for MUL_MAT plus identify the lm-head by being the
    # last matvec of the per-layer sequence (we just report any MUL_MAT
    # with the largest single-tensor weight as a proxy; the per-op
    # profile sorts by cum us so lm-head should be visible at top).
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  H2: lm-head matvec avg us per batch (M=1 TG)"
        echo "  Expected: qwen1 lm-head ~116 MB, gemma4 ~196 MB; theoretical"
        echo "  DRAM-bound floor at ~64 GB/s = 1.8-3.1 ms/token"
        echo "=========================================="
        printf "  %-10s %-12s %-12s %-12s %-15s %-15s\n" "ctx" "qwen1 avg" "gemma4 avg" "qwen1 GB/s" "gemma4 GB/s"
        for ctx in ${ctxs}; do
            local q1_avg=$(grep "OP-PROF" "${base}_qwen1_ctx${ctx}_logcat.log"                           | grep -oE 'op=MUL_MAT[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                           | sort -t= -k5 -n -r | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
            local g4_avg=$(grep "OP-PROF" "${base}_gemma4_ctx${ctx}_logcat.log"                           | grep -oE 'op=MUL_MAT[^ ]* cum=[0-9]+ us count=[0-9]+ avg=[0-9]+'                           | sort -t= -k5 -n -r | head -1 | grep -oE 'avg=[0-9]+' | cut -d= -f2)
            # qwen1 lm-head bytes = 151936 * 1536 * 0.5 (Q4_0) = 116.7 MB
            # gemma4-e2b lm-head bytes ~ 256000 * 1536 * 0.5 = 196.6 MB
            local q1_bw="n/a"
            local g4_bw="n/a"
            if [ -n "${q1_avg}" ] && [ "${q1_avg}" -gt 0 ]; then
                q1_bw=$(awk -v us="${q1_avg}" 'BEGIN { printf "%.2f", 116.7 * 1024 / us }')
            fi
            if [ -n "${g4_avg}" ] && [ "${g4_avg}" -gt 0 ]; then
                g4_bw=$(awk -v us="${g4_avg}" 'BEGIN { printf "%.2f", 196.6 * 1024 / us }')
            fi
            printf "  %-10s %-12s %-12s %-12s %-15s\n" "${ctx}" "${q1_avg:-n/a}" "${g4_avg:-n/a}" "${q1_bw}" "${g4_bw}"
        done
        echo ""
        echo "  H2 verdict: theoretical DRAM peak on 8 Elite = ~64 GB/s"
        echo "  If actual << theoretical, lm-head is DRAM-bound and not DSP-limited"
    } | tee -a "${summary_log}"

    # ---------------------------------------------------------------------
    # Non-op overhead reference (for cross-checking H3 in case H1+H2
    # turn out to be small — confirms whether 1588MB a-inv is the real
    # bottleneck or not).
    # ---------------------------------------------------------------------
    {
        echo ""
        echo "=========================================="
        echo "  Reference: a-inv us/batch at each ctx (last 5 dumps)"
        echo "=========================================="
        for ctx in ${ctxs}; do
            for model in ${models}; do
                echo ""
                echo "--- ${model} ctx=${ctx} a-inv (last 5 dumps) ---"
                grep "OP-PROF-NONOP" "${base}_${model}_ctx${ctx}_logcat.log"                     | grep -oE 'a-inv=[0-9]+\([0-9]+MB\)'                     | tail -5
            done
        done
    } | tee -a "${summary_log}"

    {
        echo ""
        echo "=========================================="
        echo "  Done."
        echo "  Share these 13 files for analysis:"
        echo "    ${summary_log}  (H1 + H2 cross-ctx comparison)"
        echo "    ${base}_qwen1_ctx{1024,4096,16384}.log (3 qwen1 terminal outputs)"
        echo "    ${base}_gemma4_ctx{1024,4096,16384}.log (3 gemma4 terminal outputs)"
        echo "    ${base}_<model>_ctx<N>_logcat.log (6 raw OP-PROF dumps)"
        echo "  Next: verify H1 (qwen1 FLASH_ATTN growth > gemma4) +"
        echo "        H2 (lm-head actual DRAM BW vs ~64 GB/s theoretical)"
        echo "=========================================="
    } | tee -a "${summary_log}"
}


function print_oplist()
{
oplist="DUP
    ADD
    ADD1
    ACC
    SUB
    MUL
    DIV
    SQR
    SQRT
    LOG
    SIN
    COS
    SUM
    SUM_ROWS
    MEAN
    ARGMAX
    COUNT_EQUAL
    REPEAT
    REPEAT_BACK
    CONCAT
    SILU_BACK
    NORM
    RMS_NORM
    RMS_NORM_BACK
    GROUP_NORM

    MUL_MAT
    MUL_MAT_ID
    OUT_PROD

    SCALE
    SET
    CPY
    CONT
    RESHAPE
    VIEW
    PERMUTE
    TRANSPOSE
    GET_ROWS
    GET_ROWS_BACK
    DIAG
    DIAG_MASK_INF
    DIAG_MASK_ZERO
    SOFT_MAX
    SOFT_MAX_BACK
    ROPE
    ROPE_BACK
    CLAMP
    CONV_TRANSPOSE_1D
    IM2COL
    IM2COL_BACK
    CONV_TRANSPOSE_2D
    POOL_1D
    POOL_2D
    POOL_2D_BACK
    UPSCALE
    PAD
    PAD_REFLECT_1D
    ARANGE
    TIMESTEP_EMBEDDING
    ARGSORT
    LEAKY_RELU

    FLASH_ATTN_EXT
    FLASH_ATTN_BACK
    SSM_CONV
    SSM_SCAN
    WIN_PART
    WIN_UNPART
    GET_REL_POS
    ADD_REL_POS
    RWKV_WKV6
    GATED_LINEAR_ATTN"

echo "opname list: "
echo ${oplist}
}


function show_usage()
{
    echo -e "\n"
    echo "Usage:"
    echo "  $0 help"
    echo "  $0 print_oplist"

    echo "  $0 update_jz_libs   (push JZ runtime .so from out/ab-test/ to device, for build)"
    echo "  $0 update_qcom_libs (push QCOM runtime .so from out/ab-test/ to device, for build_qcom)"
    echo "  $0 update_cpu_libs  (push CPU-only runtime .so from out/ab-test/ to device, for build_armcpu)"
    echo "  $0 update_ggml_libs (incremental: push AP-side libs from bin/ to device only; keep DSP skels as-is)"

    echo "  $0 build            (build JZ's ggml-hexagon backend)"
    echo "  $0 build_debug      (build JZ's ggml-hexagon backend in debug mode)"
    echo "  $0 build_qcom       (build Qualcomm's ggml-hexagon backend for performance comparison)"
    echo "  $0 build_armcpu     (build Android CPU-only reference for correctness check and troulbeshooting trick issues)"
    echo "  $0 clean"

    echo "  $0 run_testops"
    echo "  $0 run_testop     ADD/MUL_MAT/FLASH_ATTN_EXT (verify accuracy    of ADD/MUL_MAT)"
    echo "  $0 run_perfop     ADD/MUL_MAT/FLASH_ATTN_EXT (verify performance of ADD/MUL_MAT)"
    echo "  $0 run_llamacli"
    echo "  $0 run_llamabench"

    echo "  $0 run_llamacli_all     (batch test 6 models = 6 tests)"
    echo "    Log capture example:"
    echo "      $0 run_llamacli_all 2>&1 | tee log_ci_\$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_pp_only [model_alias] [round_count]"
    echo "    PP-only test: N llama-completion runs. Uses -n 1 (not -n 0) because"
    echo "    -n 0 exits before processing the prompt. -n 1 gives 1 PP batch"
    echo "    (the prompt) + 1 TG batch; OP-PROF dump 'batch#1' is the PP graph."
    echo "    With HEX_OP_PROF_DUMP_INTERVAL=1, one run = one full batch dump."
    echo "    model_alias:  default gemma4-e2b"
    echo "    round_count:  default 1 (raise only if data looks noisy)"
    echo "    Examples:"
    echo "      $0 run_pp_only              # 1 PP run on gemma4-e2b"
    echo "      $0 run_pp_only qwen3-2b 3   # 3 PP runs on qwen3-2b"
    echo "    Log capture example (run in another terminal; batch#1 = PP data):"
    echo "      adb logcat | grep --line-buffered -iE '(OP-PROF.*batch#1 |QKV skip|FFN skip|mul_mat coverage|hmx eligibility)' | tee log_pp_only_\$(date +%Y%m%d-%H%M%S).txt"
    echo "    Or capture both PP+TG for comparison:"
    echo "      adb logcat | grep --line-buffered OP-PROF | tee log_pp_only_\$(date +%Y%m%d-%H%M%S).txt"
    echo "    Or capture both all:"
    echo "      adb logcat -d -v threadtime > log_pathc_v2_$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_abtest  [rounds] [model_alias]"
    echo "    JZ vs QCOM performance comparison (requires 'build' then 'build_qcom' first)."
    echo "    rounds:       default 3"
    echo "    model_alias:  default gemma4-e2b"
    echo "    Examples:"
    echo "      $0 run_abtest                      # 3 rounds, gemma4-e2b"
    echo "      $0 run_abtest 5                    # 5 rounds, gemma4-e2b"
    echo "      $0 run_abtest 3 qwen3-2b           # 3 rounds, qwen3-2b"
    echo "    Log capture example:"
    echo "      $0 run_abtest 2>&1 | tee log_abtest_\$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_abtest_all [rounds]"
    echo "    Batch AB test across all 6 models (qwen3-2b, qwen3-4b, qwen3-9b, gemma4-e2b, gemma4-e4b, qwen1, llama3)."
    echo "    rounds: default 3"
    echo "    Log capture example:"
    echo "      $0 run_abtest_all 2>&1 | tee log_abtest_all_\$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_qwen1_tg_prof"
    echo "    Kimi-K3 5.8.4-F: qwen1 TG root cause profiling."
    echo "    Forces M=1 (ubatch=1, batch=1) for pure single-token TG with HEX_OP_PROF=1."
    echo "    Runs qwen1 (MHA 1:1) vs gemma4-e2b (GQA 8:1) to validate three hypotheses:"
    echo "      H1 FLASH_ATTN: MHA KV reads 8x GQA, dominant if MHA-specific"
    echo "      H2 lm-head:    Q6_K/Q4_0 repack matvec bandwidth sub-expected"
    echo "      H3 KV inval:   per-token invalidation overhead on MHA's larger K/V"
    echo "    Output: qwen1_tg_prof_<timestamp>.log with per-op cum and non-op overhead."
    echo -e "\n"

    echo "  $0 run_qwen3_9b_tg_prof"
    echo "    5.8.5-F2: qwen3.5-9B TG 5x gap root cause profiling."
    echo "    Same M=1 + HEX_OP_PROF=1 setup as run_qwen1_tg_prof, but tests qwen3.5-9B (GQA 4:1,"
    echo "    40 layers, 9B params) against gemma4-e2b (GQA 8:1, 35 layers, 2B params) as a"
    echo "    GVA-vs-GVA reference. Targets the 5x PP/TG gap with QCOM (PP 23.9 vs 135, TG 1.32 vs 7)."
    echo "    Hypotheses: H1 graph split (batch_calls >> 256), H2 missing op (specific op falls"
    echo "    back to slow path), H3 a-inv explosion (5x more params = 5x more activation)."
    echo "    Output: qwen3_9b_tg_prof_<timestamp>.log with per-op cum and non-op overhead."
    echo -e "\n"

    echo "  $0 run_force_opfusion_in_pp_all"
    echo "    Batch force_opfusion_in_pp=0 baseline verification across 6 models."
    echo "    Per model: 1 llama-completion run + logcat capture in background."
    echo "    Outputs 2 logs per model with unified naming:"
    echo "      log_forceopfusioninpp_<model>_<ts>_terminal.txt"
    echo "      log_forceopfusioninpp_<model>_<ts>_logcat.txt"
    echo -e "\n"

    echo "  $0 run_llamacli   [model_alias]"
    echo "  Model aliases for run_llamacli:"
    echo "    qwen3-2b      -> Qwen3.5-2B-Q4_0.gguf"
    echo "    qwen3-4b      -> Qwen3.5-4B-Q4_0.gguf"
    echo "    qwen3-9b      -> Qwen3.5-9B-Q4_0.gguf"
    echo "    gemma4-e2b    -> gemma-4-E2B-it-Q4_0.gguf (2.9 GiB)"
    echo "    gemma4-e4b    -> gemma-4-E4B_q4_0-it.gguf (4.9 GiB, stress test for mirror/eviction)"
    echo "    qwen1         -> qwen1_5-1_8b-chat-q4_0.gguf"
    echo "    llama3        -> Llama-3.2-1B-Instruct-Q4_0.gguf"
    echo "    (default)     -> gemma-4-E2B-it-Q4_0.gguf"
    echo "  Examples:"
    echo "    $0 run_llamacli qwen3-2b     # test qwen3-2b"
    echo "    $0 run_llamacli gemma4-e2b   # test gemma4-e2b"
    echo "    $0 run_llamacli gemma4-e4b   # test gemma4-e4b (mirror stress test)"
    echo -e "\n"

    echo "  $0 run_stresstest"
    echo "    Long-context stress test with gemma4-E4B (~5500 token prompt)."
    echo "    Fills KV cache to trigger mirror/eviction, exercising allocator"
    echo "    split/coalesce paths. Requires gemma4-E4B model on device."
    echo "    Log capture example:"
    echo "      $0 run_stresstest 2>&1 | tee log_stress_\$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_ubatchtest  [model_alias] [ubatch_csv]"
    echo "    Sweep --ubatch-size values, dump raw per-ubatch logs (no in-shell parsing)."
    echo "    model_alias:  gemma4-e2b (default) | qwen3-2b | qwen3-4b | gemma4-e4b | qwen1 | llama3"
    echo "    ubatch_csv:   32,64,128,512,1024 (default)"
    echo "    Examples:"
    echo "      $0 run_ubatchtest                          # gemma4-e2b + 32/64/128/512/1024"
    echo "      $0 run_ubatchtest qwen3-2b                 # qwen3-2b + 32/64/128/512/1024"
    echo "      $0 run_ubatchtest qwen3-2b 32,128,512      # qwen3-2b + 32/128/512"
    echo "      $0 run_ubatchtest qwen3-2b 64              # qwen3-2b + 64"
    echo "    Log capture example:"
    echo "      $0 run_ubatchtest 2>&1 | tee log_ci_\$(date +%Y%m%d-%H%M%S).txt"

    echo "  $0 run_flash_lmhead_prof"
    echo "    Sweep ctx_size to verify H1 (FLASH_ATTN MHA vs GQA growth) and"
    echo "    H2 (lm-head matvec actual DRAM bandwidth vs ~64 GB/s peak)."
    echo "    Runs 6 tests: qwen1 + gemma4-e2b crossed with ctx in {1024, 4096, 16384}."
    echo "    Each (model, ctx) writes its own log + logcat dump; summary"
    echo "    extracts FLASH_ATTN avg us and top MUL_MAT (proxy for lm-head)"
    echo "    per (model, ctx) plus growth ratio and DRAM bandwidth estimate."
    echo "    Note: HEX_OP_PROF must be enabled at build (default on)."
    echo "    Log capture example:"
    echo "      $0 run_flash_lmhead_prof 2>&1 | tee log_h1h2_\$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_ubatchtest_all"
    echo "    Batch ubatch sweep across 6 models x 5 ubatches = 30 tests."
    echo "    models:    gemma4-e2b, qwen3-2b, qwen3-4b, qwen1, llama3, gemma4-e4b"
    echo "    ubatches:  32, 64, 128, 512, 1024"
    echo "    Log capture example:"
    echo "      $0 run_ubatchtest_all 2>&1 | tee log_ci_\$(date +%Y%m%d-%H%M%S).txt"
}


######## part-4: entry point  ########

show_pwd

check_commands_in_host
check_android_phone
check_and_download_ndk
check_and_download_opencl_sdk
check_and_download_hexagon_sdk
check_prebuilt_models

if [ $# == 0 ]; then
    show_usage
    exit 1
elif [ $# == 1 ]; then
    if [ "$1" == "-h" ]; then
        show_usage
        exit 1
    elif [ "$1" == "help" ]; then
        show_usage
        exit 1
    elif [ "$1" == "print_oplist" ]; then
        print_oplist
        exit 1
    elif [ "$1" == "update_ggml_libs" ]; then
        update_ggml_libs
        exit 1
    elif [ "$1" == "update_jz_libs" ]; then
        update_jz_libs
        exit 0
    elif [ "$1" == "update_qcom_libs" ]; then
        update_qcom_libs
        exit 0
    elif [ "$1" == "update_cpu_libs" ]; then
        update_cpu_libs
        exit 0
    elif [ "$1" == "build" ]; then
        build_ggml_hexagon
        exit 0
    elif [ "$1" == "build_debug" ]; then
        build_ggml_hexagon_debug
        exit 0
    elif [ "$1" == "build_qcom" ]; then
        build_ggml_hexagon_qcom
        exit 0
    elif [ "$1" == "build_armcpu" ]; then
        build_armcpu
        exit 0
    elif [ "$1" == "clean" ]; then
        remove_temp_dir
        exit 0
    elif [ "$1" == "run_testops" ]; then
        run_test-ops
        exit 0
    elif [ "$1" == "run_llamacli" ]; then
        run_llamacli
        exit 0
    elif [ "$1" == "run_stresstest" ]; then
        run_stresstest
        exit 0
    elif [ "$1" == "run_pp_only" ]; then
        run_pp_only
        exit 0
    elif [ "$1" == "run_llamabench" ]; then
        run_llamabench
        exit 0
    elif [ "$1" == "run_llamacli_all" ]; then
        run_llamacli_all
        exit 0
    elif [ "$1" == "run_abtest" ]; then
        run_abtest
        exit 0
    elif [ "$1" == "run_abtest_all" ]; then
        run_abtest_all
        exit 0
    elif [ "$1" == "run_force_opfusion_in_pp_all" ]; then
        run_force_opfusion_in_pp_all
        exit 0
    elif [ "$1" == "run_ubatchtest" ]; then
        run_ubatchtest
        exit 0
    elif [ "$1" == "run_ubatchtest_all" ]; then
        run_ubatchtest_all
        exit 0
    elif [ "$1" == "run_qwen1_tg_prof" ]; then
        run_qwen1_tg_prof
        exit 0
    elif [ "$1" == "run_qwen3_9b_tg_prof" ]; then
        run_qwen3_9b_tg_prof
    elif [ "$1" == "run_qwen3_9b_only" ]; then
        run_qwen3_9b_only
        exit 0
    elif [ "$1" == "run_flash_lmhead_prof" ]; then
        run_flash_lmhead_prof
        exit 0
    else
        show_usage
        exit 1
    fi
elif [ $# == 2 ]; then
#TODO: check opname in oplist
#opname can be found via print_oplist:

    if [ "$1" == "run_testop" ]; then
        opname=$2
        run_test-op
        exit 0
    elif [ "$1" == "run_perfop" ]; then
        opname=$2
        run_perf-op
        exit 0
    elif [ "$1" == "run_llamacli" ]; then
        if [ -z "$(resolve_model_name "$2")" ]; then
            echo "ERROR: unknown model alias '$2'. Valid aliases: qwen3-2b, qwen3-4b, qwen3-9b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            show_usage
            exit 1
        fi
        run_llamacli "$2"
        exit 0
    elif [ "$1" == "run_pp_only" ]; then
        if [ -n "$2" ] && [ -z "$(resolve_model_name "$2")" ]; then
            echo "ERROR: unknown model alias '$2'. Valid aliases: qwen3-2b, qwen3-4b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            show_usage
            exit 1
        fi
        run_pp_only "$2"
        exit 0
    elif [ "$1" == "run_threadsafety" ]; then
        run_threadsafety
        exit 0
    elif [ "$1" == "run_ubatchtest" ]; then
        run_ubatchtest "$2"
        exit 0
    elif [ "$1" == "run_abtest" ]; then
        run_abtest "$2"
        exit 0
    elif [ "$1" == "run_abtest_all" ]; then
        run_abtest_all "$2"
        exit 0
    else
        show_usage
        exit 1
    fi
elif [ $# == 3 ]; then
    if [ "$1" == "run_perfop" ]; then
        opname=$2
        run_perf-op
        exit 0
    elif [ "$1" == "run_testop" ]; then
        opname=$2
        run_test-op
        exit 0
    elif [ "$1" == "run_llamacli" ]; then
        if [ -z "$(resolve_model_name "$2")" ]; then
            echo "ERROR: unknown model alias '$2'. Valid aliases: qwen3-2b, qwen3-4b, qwen3-9b, gemma4-e2b, gemma4-e4b, qwen1, llama3"
            show_usage
            exit 1
        fi
        run_llamacli "$2"
        exit 0
    elif [ "$1" == "run_ubatchtest" ]; then
        run_ubatchtest "$2" "$3"
        exit 0
    elif [ "$1" == "run_abtest" ]; then
        run_abtest "$2" "$3"
        exit 0
    else
        show_usage
        exit 1
    fi
elif [ $# == 4 ]; then
    show_usage
    exit 1
else
    show_usage
    exit 1
fi
