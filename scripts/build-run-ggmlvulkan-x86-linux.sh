#!/usr/bin/env bash
#
# build&verify ggml-vulkan on x86-linux
#
set -e

######## part-1: public macros & vars ########

PWD=`pwd`
PROJECT_HOME_PATH=`pwd`
PROJECT_ROOT_PATH=${PROJECT_HOME_PATH}
HOST_CPU_COUNTS=`cat /proc/cpuinfo | grep "processor" | wc | awk '{print int($1)}'`

VERBOSE=OFF
VERBOSE=ON

#path of built artifacts
LOCAL_BUILD_DIR=${PROJECT_ROOT_PATH}/out/ggmlvulkan-x86-linux

#running path on local x86-linux
LOCAL_PATH=${LOCAL_BUILD_DIR}/bin/

TOOLCHAIN_PATH=${PROJECT_ROOT_PATH}/prebuilts

VULKAN_SDK_VERSION=1.4.304.1
VULKAN_SDK_NAME=vulkansdk-linux-x86_64-${VULKAN_SDK_VERSION}.tar.xz
VULKAN_SDK_URL=https://sdk.lunarg.com/sdk/download/${VULKAN_SDK_VERSION}/linux/${VULKAN_SDK_NAME}
VULKAN_SDK_PATH=${TOOLCHAIN_PATH}/Vulkan_SDK

######## part-2: prompt and LLM models ########
#supported models will be downloadded automatically in check_prebuilt_models() when running this script at the first time

LLM_PATH=/run/media/zhouwg/0893c374-f64c-4121-9192-21e7fd97edef/LLM
GGUF_MODEL_NAME=${LLM_PATH}/gemma-4-E2B-it-Q4_0.gguf

# Model aliases for quick testing of multiple models
# Usage: ./scripts/build-run-ggmlvulkan-x86-linux.sh run_llamacli <alias>
# 8 models for PP & TG Performance Comparison: ggml-vulkan x86-linux vs ggml-hexagon on Android phone
# automatically downloadded on first run
#   minicpm5-1b         -> minicpm5-1b-q4_0.gguf
#   qwen3-2b            -> Qwen3.5-2B-Q4_0.gguf
#   qwen3-4b            -> Qwen3.5-4B-Q4_0.gguf
#   spark-1b            -> Spark-X2.5-1.7B.gguf
#   gemma4-e2b          -> gemma-4-E2B-it-Q4_0.gguf (2.9 GiB, default test model)
#   gemma4-e4b          -> gemma-4-E4B_q4_0-it.gguf (4.9 GiB)
#   nanbeige-3b         -> Nanbeige_Nanbeige4.2-3B-Q4_0.gguf
#   qwen3-9b            -> Qwen3.5-9B-Q4_0.gguf
#
#models for development purposes
#   llama3              -> Llama-3.2-1B-Instruct-Q4_0.gguf
#   qwen1               -> qwen1_5-1_8b-chat-q4_0.gguf
#   nanbeige-3b-q80     -> Nanbeige_Nanbeige4.2-3B-Q8_0.gguf
#   minicpm5-1b-q80     -> MiniCPM5-1B-Q8_0.gguf
#   minicpm5-1b-q4-k-m  -> MiniCPM5-1B-Q4_K_M.gguf
#   minicpm5-2b-q80     -> MiniCPM5-2B-Q8_0.gguf
#   spark-4b            -> Spark-X2.6-4B-Q8_0.gguf
#   qwen3-27b           -> Qwen3.8-27B-Q4_0.gguf (x86-linux only, this alias maps to Ternary-Bonsai-2-27B-PTQ1_0.gguf in build-run-ggmlhexagon-android.sh)
function resolve_model_name()
{
    case "$1" in
        minicpm5-1b)        echo "${LLM_PATH}/minicpm5-1b-q4_0.gguf";;
        qwen3-2b)           echo "${LLM_PATH}/Qwen3.5-2B-Q4_0.gguf" ;;
        qwen3-4b)           echo "${LLM_PATH}/Qwen3.5-4B-Q4_0.gguf" ;;
        spark-1b)           echo "${LLM_PATH}/Spark-X2.5-1.7B.gguf";;
        gemma4-e2b)         echo "${LLM_PATH}/gemma-4-E2B-it-Q4_0.gguf" ;;
        gemma4-e4b)         echo "${LLM_PATH}/gemma-4-E4B_q4_0-it.gguf" ;;
        nanbeige-3b)        echo "${LLM_PATH}/Nanbeige_Nanbeige4.2-3B-Q4_0.gguf";;
        qwen3-9b)           echo "${LLM_PATH}/Qwen3.5-9B-Q4_0.gguf" ;;
        llama3)             echo "${LLM_PATH}/Llama-3.2-1B-Instruct-Q4_0.gguf" ;;
        qwen1)              echo "${LLM_PATH}/qwen1_5-1_8b-chat-q4_0.gguf" ;;
        nanbeige-3b-q80)    echo "${LLM_PATH}/Nanbeige_Nanbeige4.2-3B-Q8_0.gguf";;
        minicpm5-1b-q80)    echo "${LLM_PATH}/MiniCPM5-1B-Q8_0.gguf";;
        minicpm5-1b-q4-k-m) echo "${LLM_PATH}/MiniCPM5-1B-Q4_K_M.gguf";;
        minicpm5-2b-q80)    echo "${LLM_PATH}/MiniCPM5-2B-Q8_0.gguf";;
        spark-4b)           echo "${LLM_PATH}/Spark-X2.6-4B-Q8_0.gguf";;
        qwen3-27b)          echo "${LLM_PATH}/Qwen3.8-27B-Q4_0.gguf" ;;
        aion-2b)            echo "${LLM_PATH}/Aion-1.0-Instruct-2.3B-AD-Q4_K_M.gguf";;
        inkling-2)          echo "${LLM_PATH}/Inkling-2-Mini-UD-IQ2_XXS.gguf";;
        nemotron-3b)        echo "${LLM_PATH}/NVIDIA-Nemotron-3.5-Bolt-E4B-Q8_0.gguf";;
        *)                  echo "" ; return 1 ;;
    esac
}

PROMPT_STRING="Hello, good morning, you are a powerful domain expert and know many things, now pls help to introduce the movie Once Upon a Time in America briefly, pls pay attention short then 1000 words\n"
PROMPT_STRING="pls introduce FHS and security model in Linux OS briefly\n"

#running_params=" -ngl 99 -t 6 -n 256 --no-warmup --load-mode none --poll 1000 --cpu-mask 0xfc --cpu-strict 1 --ctx-size 8192 --ubatch-size 1024 -fa on"
running_params=" -ngl 99 -t 6 --ctx-size 8192 --ubatch-size 64 --poll 1000 --no-warmup --load-mode none -fa on --jinja -st"
running_params_for_ci=" -ngl 99 -t 6 -n 256 --ctx-size 8192 --ubatch-size 64 --poll 1000 --no-warmup --load-mode none -fa on --jinja -st"
running_params=" -ngl 99 -t 6 --ctx-size 8192 --ubatch-size 64 --poll 1000 --no-warmup --load-mode none -fa on --jinja -st --reasoning-budget 128 --temp 0.2 --top-p 0.9"

######## part-3: utilities and functions ########

function dump_vars()
{
    echo -e "VULKAN_SDK:          ${VULKAN_SDK}"
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
    check_command_in_host md5sum
    check_command_in_host ninja
}


function build_x86_linux
{
    cmake -H. -B${LOCAL_BUILD_DIR} -DCMAKE_BUILD_TYPE=Release -DGGML_VULKAN=ON -DLLAMA_CUDA=OFF -DGGML_OPENMP=OFF -DGGML_OPENCL=OFF -DGGML_CCACHE=OFF -DLLAMA_CURL=OFF -DGGML_LLAMAFILE=ON -DCMAKE_C_FLAGS="${extra_flags}" -DCMAKE_CXX_FLAGS="${extra_flags}" -DCMAKE_VERBOSE_MAKEFILE:BOOL=${VERBOSE} -DLLAMA_BUILD_TESTS=ON -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_APP=OFF -DLLAMA_BUILD_UI=ON -DLLAMA_USE_PREBUILT_UI=OFF -DLLAMA_OPENSSL=OFF
    cd ${LOCAL_BUILD_DIR}
    make -j${HOST_CPU_COUNTS}
    show_pwd
    cd -
}


function remove_temp_dir()
{
    if [ -d ${LOCAL_BUILD_DIR} ]; then
        echo "remove ${LOCAL_BUILD_DIR} directory"
        rm -rf ${LOCAL_BUILD_DIR}
    fi
}


function build_ggml_vulkan_x86_linux()
{
    show_pwd
    dump_vars
    #remove_temp_dir
    build_x86_linux
}


function check_and_download_vulkan_sdk()
{
    is_vulkan_sdk_exist=1

    if [ ! -d ${VULKAN_SDK_PATH} ]; then
        echo -e "VULKAN_SDK_PATH ${VULKAN_SDK_PATH} not exist\n"
        is_vulkan_sdk_exist=0
    fi

    if [ ${is_vulkan_sdk_exist} -eq 0 ]; then
        mkdir -p ${VULKAN_SDK_PATH}

        if [ ! -f ${VULKAN_SDK_NAME} ]; then
            echo -e "download vulkan sdk from ${VULKAN_SDK_URL}...\n"
            wget --no-config --quiet --show-progress -O ${VULKAN_SDK_PATH}/${VULKAN_SDK_NAME} ${VULKAN_SDK_URL}
            if [ $? -ne 0 ]; then
                printf "failed to download Vulkan SDK to %s \n" "${VULKAN_SDK_PATH}"
                exit 1
            fi
        fi
        printf "decompress ${VULKAN_SDK_NAME}..."
        # -C, not cd: leaving this function in prebuilts/ would run the cmake that
        # follows in the wrong directory on a fresh checkout (the SDK download path).
        tar Jxf ${VULKAN_SDK_PATH}/${VULKAN_SDK_NAME} -C ${VULKAN_SDK_PATH}
    else
        printf "VULKAN SDK already exist:    ${VULKAN_SDK_PATH} \n\n"
    fi

    export VULKAN_SDK=${VULKAN_SDK_PATH}/${VULKAN_SDK_VERSION}/x86_64
    export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${VULKAN_SDK}/lib
    export PATH=$PATH:${VULKAN_SDK}/bin
    export VK_LAYER_PATH=$VULKAN_SDK/share/vulkan/explicit_layer.d
    export VK_ADD_LAYER_PATH=$VULKAN_SDK/share/vulkan/explicit_layer.d
    export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$VULKAN_SDK/lib/pkgconfig/
    export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:$VULKAN_SDK:$VULKAN_SDK/lib/VulkanLoader
}


function check_and_download_model()
{
    set +e

    model_name=$1
    model_url=$2

    ls ${LLM_PATH}/${model_name}
    if [ $? -eq 0 ]; then
        printf "the prebuild LLM model ${model_name} already exist\n"
    else
        printf "the prebuild LLM model ${model_name} not exist\n"
        printf "downloading from ${model_url}\n"
        wget --no-config --quiet --show-progress -O ${PROJECT_ROOT_PATH}/models/${model_name} ${model_url}
        /bin/cp -fv ${PROJECT_ROOT_PATH}/models/${model_name} ${LLM_PATH}
    fi

    set -e
}


function check_prebuilt_models()
{
    set +e

    #8 models for PP & TG Performance Comparison: ggml-vulkan x86-linux vs ggml-hexagon on Android phone

    #635 MiB
    check_and_download_model minicpm5-1b-q4_0.gguf               https://huggingface.co/Elmermoreno/MiniCPM5-1B-Q4_0-GGUF/resolve/main/minicpm5-1b-q4_0.gguf

    #1.2 GiB
    check_and_download_model Qwen3.5-2B-Q4_0.gguf         https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_0.gguf

    #2.58 GiB
    check_and_download_model Qwen3.5-4B-Q4_0.gguf         https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_0.gguf

    #3.2 GiB
    check_and_download_model Spark-X2.5-1.7B.gguf               https://huggingface.co/XHToken/Spark-X2.5-1.7B-GGUF/resolve/main/Spark-X2.5-1.7B.gguf

    #2.9 GiB
    check_and_download_model gemma-4-E2B-it-Q4_0.gguf     https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_0.gguf

    #4.9 GiB
    check_and_download_model gemma-4-E4B_q4_0-it.gguf     https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf

    #2.4 GiB
    check_and_download_model Nanbeige_Nanbeige4.2-3B-Q4_0.gguf   https://huggingface.co/bartowski/Nanbeige_Nanbeige4.2-3B-GGUF/resolve/main/Nanbeige_Nanbeige4.2-3B-Q4_0.gguf

    #5.1 GiB
    check_and_download_model Qwen3.5-9B-Q4_0.gguf         https://huggingface.co/unsloth/Qwen3.5-9B-GGUF/resolve/main/Qwen3.5-9B-Q4_0.gguf


    #temporary models for development purposes

    #737 MiB
    #check_and_download_model Llama-3.2-1B-Instruct-Q4_0.gguf     https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_0.gguf

    #1.12 GiB
    #check_and_download_model qwen1_5-1_8b-chat-q4_0.gguf  https://huggingface.co/Qwen/Qwen1.5-1.8B-Chat-GGUF/resolve/main/qwen1_5-1_8b-chat-q4_0.gguf

    #4.2 GiB
    #check_and_download_model Nanbeige_Nanbeige4.2-3B-Q8_0.gguf   https://huggingface.co/bartowski/Nanbeige_Nanbeige4.2-3B-GGUF/resolve/main/Nanbeige_Nanbeige4.2-3B-Q8_0.gguf

    #1.1 GiB
    #check_and_download_model MiniCPM5-1B-Q8_0.gguf               https://huggingface.co/openbmb/MiniCPM5-1B-GGUF/resolve/main/MiniCPM5-1B-Q8_0.gguf

    #7.7 GiB
    #check_and_download_model Spark-X2.5-4B.gguf                  https://huggingface.co/XHToken/Spark-X2.5-4B-GGUF/resolve/main/Spark-X2.5-4B.gguf

    set -e
}


function run_llamaversion()
{
    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-completion --version"

    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-completion --version
}


function run_llamacli()
{
    local model_name=""
    local model_path=""

    if [ $# -ge 1 ]; then
        model_name="$1"
        model_path=$(resolve_model_name "$model_name")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_name'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            exit 1
        fi
    else
        model_path="${GGUF_MODEL_NAME}"
    fi

    local vulkan_running_envs="export GGML_VK_MEMORY_LOGGER=1 export GGML_VK_PERF_LOGGER=1"
    local vulkan_running_envs="export GGML_VK_ALLOW_SYSMEM_FALLBACK=1"
    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-completion ${running_params} -m ${model_path} -p ${PROMPT_STRING@Q}"
    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${vulkan_running_envs} \
               && ${LOCAL_PATH}/llama-completion ${running_params} -m ${model_path} -p "${PROMPT_STRING}"

}

function run_llamacli_for_ci()
{
    local model_name=""
    local model_path=""

    if [ $# -ge 1 ]; then
        model_name="$1"
        model_path=$(resolve_model_name "$model_name")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_name'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            exit 1
        fi
    else
        model_path="${GGUF_MODEL_NAME}"
    fi

    local vulkan_running_envs="export GGML_VK_MEMORY_LOGGER=1 export GGML_VK_PERF_LOGGER=1"
    local vulkan_running_envs="export GGML_VK_ALLOW_SYSMEM_FALLBACK=1"
    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-completion ${running_params_for_ci} -m ${model_path} -p ${PROMPT_STRING@Q}"
    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${vulkan_running_envs} \
               && ${LOCAL_PATH}/llama-completion ${running_params_for_ci} -m ${model_path} -p "${PROMPT_STRING}"


}


#running llama-server on local x86-linux
function run_llamaserver()
{
    local model_name=""
    local model_path=""
    local server_running_params=" -ngl 99 -t 6 --ctx-size 8192 --ubatch-size 64 --poll 1000 --no-warmup --load-mode none -fa on -np 1 --host 0.0.0.0"

    if [ $# -ge 1 ]; then
        model_name="$1"
        model_path=$(resolve_model_name "$model_name")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_name'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            exit 1
        fi
    else
        model_path="${GGUF_MODEL_NAME}"
    fi

    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-server ${server_running_params} -m ${model_path}"
    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-server ${server_running_params} -m ${model_path}
}


function run_llamabench()
{
    local model_name=""
    local model_path=""

    if [ $# -ge 1 ]; then
        model_name="$1"
        model_path=$(resolve_model_name "$model_name")
        if [ -z "$model_path" ]; then
            echo "ERROR: unknown model alias '$model_name'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            exit 1
        fi
    else
        model_path="${GGUF_MODEL_NAME}"
    fi

    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-bench -t 6 --poll 1000 -ngl 99 -fa 1 --ubatch-size 1024 -p 200,500,800,1024 -n 128 -m ${model_path}"

    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/llama-bench -t 6 --poll 1000 -ngl 99 -fa 1 --ubatch-size 1024 -p 200,500,800,1024 -n 128 -m ${model_path}
}


function run_llamacli_all()
{
    local models=("minicpm5-1b" "qwen3-2b" "qwen3-4b" "spark-1b" "gemma4-e2b" "gemma4-e4b" "nanbeige-3b" "qwen3-9b" "llama3" "qwen1" "nanbeige-3b-q80" "minicpm5-1b-q80" "minicpm5-1b-q4-k-m" "minicpm5-2b-q80" "spark-4b")

    local total=${#models[@]}
    local count=0

    echo "=============================================="
    echo "  Batch inference test: ${#models[@]} models = ${total} tests"
    echo "=============================================="

    for model in "${models[@]}"; do
        count=$(( count + 1 ))
        echo ""
        echo "--- [${count}/${total}] model=${model} ---"
        run_llamacli_for_ci "${model}"
    done

    echo ""
    echo "=============================================="
    echo "  Batch inference test complete: ${total} tests done"
    echo "=============================================="
}


function run_test-ops()
{
    prog_name=test-backend-ops

    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/${prog_name} test"


    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/${prog_name} test

}


function run_test-op()
{
    prog_name=test-backend-ops
    prog_param="-o ${opname}"

    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/${prog_name} test ${prog_param}"

    echo "\n"
    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/${prog_name} test ${prog_param}

}


function run_perf-op()
{
    prog_name=test-backend-ops

    echo "cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/${prog_name} perf -o ${opname}"

    echo "\n"
    cd ${LOCAL_PATH} \
               && export LD_LIBRARY_PATH=${LOCAL_PATH} \
               && ${LOCAL_PATH}/${prog_name} perf -o ${opname}

}


function show_usage()
{
    echo -e "\n"
    echo "Usage:"
    echo "  $0 help"

    echo "  $0 build"
    echo "  $0 clean"

    echo "  $0 run_llamaversion         (display llama-cpp version information, e.g. version: 0.2.0-dev (build 11120, commit 9f03708a9))"
    echo "  $0 run_testops"
    echo "  $0 run_testop     ADD/MUL_MAT/FLASH_ATTN_EXT (verify accuracy    of ADD/MUL_MAT)"
    echo "  $0 run_perfop     ADD/MUL_MAT/FLASH_ATTN_EXT (verify performance of ADD/MUL_MAT)"
    echo -e "\n"

    echo "  $0 run_llamacli_all     (batch test 15 models = 15 tests)"
    echo "    Log capture example:"
    echo "      $0 run_llamacli_all 2>&1 | tee log_ci_\$(date +%Y%m%d-%H%M%S).txt"
    echo -e "\n"

    echo "  $0 run_llamacli     [model_alias]"
    echo "  $0 run_llamabench   [model_alias]"
    echo "  $0 run_llamaserver  [model_alias]"
    echo "  Model aliases for run_llamacli:"
    echo "    qwen3-2b      -> Qwen3.5-2B-Q4_0.gguf"
    echo "    qwen3-4b      -> Qwen3.5-4B-Q4_0.gguf"
    echo "    qwen3-9b      -> Qwen3.5-9B-Q4_0.gguf"
    echo "    gemma4-e2b    -> gemma-4-E2B-it-Q4_0.gguf"
    echo "    gemma4-e4b    -> gemma-4-E4B_q4_0-it.gguf"
    echo "    nanbeige-3b   -> Nanbeige_Nanbeige4.2-3B-Q4_0.gguf"
    echo "    minicpm5-1b   -> minicpm5-1b-q4_0.gguf"
    echo "    spark-1b      -> Spark-X2.5-1.7B.gguf"
    echo "    spark-4b      -> Spark-X2.6-4B-Q8_0.gguf"
    echo "    qwen3-27b     -> Qwen3.8-27B-Q4_0.gguf (x86-linux only, maps to Ternary-Bonsai-2-27B-PTQ1_0.gguf in ggml-hexagon android)"
    echo "  Examples:"
    echo "    $0 run_llamacli/run_llamabench              # run gemma4-e2b inference test on x86-linux"
    echo "    $0 run_llamacli/run_llamabench qwen3-2b     # test qwen3-2b"
    echo "    $0 run_llamacli/run_llamabench qwen3-4b     # test qwen3-4b"
    echo "    $0 run_llamacli/run_llamabench gemma4-e2b   # test gemma4-e2b"
    echo "    $0 run_llamacli/run_llamabench gemma4-e4b   # test gemma4-e4b"
    echo "    $0 run_llamacli/run_llamabench spark-1b     # test spark-1b"
    echo -e "\n"
}


######## part-4: entry point  ########

show_pwd
check_commands_in_host
check_and_download_vulkan_sdk
#check_prebuilt_models

dump_vars

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
    elif [ "$1" == "build" ]; then
        build_ggml_vulkan_x86_linux
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
    elif [ "$1" == "run_llamaversion" ]; then
        run_llamaversion
        exit 0
    elif [ "$1" == "run_llamaserver" ]; then
        run_llamaserver
        exit 0
    elif [ "$1" == "run_llamabench" ]; then
        run_llamabench
        exit 0
    elif [ "$1" == "run_llamacli_all" ]; then
        run_llamacli_all
        exit 0
    else
        show_usage
        exit 1
    fi
elif [ $# == 2 ]; then
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
            echo "ERROR: unknown model alias '$2'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            show_usage
            exit 1
        fi
        run_llamacli "$2"
        exit 0
    elif [ "$1" == "run_llamabench" ]; then
        if [ -z "$(resolve_model_name "$2")" ]; then
            echo "ERROR: unknown model alias '$2'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            show_usage
            exit 1
        fi
        run_llamabench "$2"
        exit 0
    elif [ "$1" == "run_llamaserver" ]; then
        if [ -z "$(resolve_model_name "$2")" ]; then
            echo "ERROR: unknown model alias '$2'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            show_usage
            exit 1
        fi
        run_llamaserver "$2"
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
            echo "ERROR: unknown model alias '$2'. Valid aliases: minicpm5-1b, qwen3-2b, qwen3-4b, spark-1b, gemma4-e2b, gemma4-e4b, nanbeige-3b, qwen3-9b, llama3, qwen1, nanbeige-3b-q80, minicpm5-1b-q80, minicpm5-1b-q4-k-m, minicpm5-2b-q80, spark-4b, qwen3-27b"
            show_usage
            exit 1
        fi
        run_llamacli "$2"
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
