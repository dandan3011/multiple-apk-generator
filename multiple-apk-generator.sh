#!/bin/bash

#
# author: tongyapeng
# date  :  2015-11-25
# 使用说明：
# 1、在dg-resource中新建输出目标相关配置路径，如果是完形填空对应的包文件夹名字是colze-xxx，如果是阅读理解对应的包文件夹名字是comprehension-xxx
# 2、在第一步新建的目录下面创建dgconfig.txt，使用规定的描述语言描述输出apk之前做的一些资源替换操作
# 3、执行此脚本，命令行下cd到项目根目录下(OnlineEnglishEducate)  执行./dynamic-generate.sh
#
# 描述语言说明:
# 1、配置目标生成项目的包名为${1}
#   packname com.example.comprehension
#
# 2、使用${2}匹配并替换${0}文件中的${1}
#   match-file src/main/AndroidManifest.xml com.example.comprehension com.example.colze
#
# 3、使用${2}匹配并替换${0}为根目录下的所有文件中的${1}
#   match-all src/main/java/ com.example.comprehension.R com.example.colze.R
#
# 4、使用${1}的对应文件替换${2}对应的文件
#   copy_file ic_launcher.png src/main/res/drawable-hdpi/ic_launcher.png
#
# 5、#把${2}文件中的第${1}行的内容替换成${2}对应内容
#   replace-line 4 src/main/res/values/strings.xml <string name="app_name">完形填空</string>
#
#
# 注: 最终输出的apk，
# 注: 在描述文件中以#开头的是注释，会被忽略掉
# 注: 描述语言以行为单位 ，按空格分隔，第一个单词为动作，后面的依次为${1}  ${2}  ${3}  ......
# 注: 模版文件目录已colze_或者comprehension_开头
# 注: 描述文件(metadatd.dsl)参数中不能出现空格
#

LANG=zh_CN.UTF-8

IFS=$'\n'

#是否是调试状态
DEBUG=0

#shell执行目录
PWD=$(pwd)

#工程目录
PROJECT_DIR=$(pwd)

#工程名字
PROJECT_NAME="OnlineEnglishEducate"

#工作目录
WORK_DIR="$HOME/dgwork"
if [ ${DEBUG} != 0 ];then
    WORK_DIR="$HOME/Desktop/dgwork"
    clear
fi

#元数据目录
METADATD_DIR="${PROJECT_DIR}/dg-resource"

#目录apk输出路径
TARGET_APK_DIR="${METADATD_DIR}/out"

#工程镜像地址
PROJECT_MIRRORING="${WORK_DIR}/${PROJECT_NAME}"

#描述文件名
DSL_FILE_NAME="metadata.dsl"

#插件函数===start

#替换多个文件中的内容 ${1}: 目标module ${2}: 从这个路径下开始搜索 ${3}: 被替换的内容 ${4}: 目标内容
function match_all() {
    dlog "match_all target: ${1},search_root: ${2},src_str: ${3},dest_str: ${4}"
    search_path="${PROJECT_MIRRORING}/${1}/${2}"
    dlog "search_path: ${search_path}"

    find ${search_path} | while read line
    do
        #忽略掉文件夹
        if [ -f ${line} ];then
            cat $line | grep $3
            if [ $? == 0 ];then
                  dlog "match_all : ${line}"
            fi
            sed -i.dgtmp "s/${3}/${4}/g" ${line}
            rm "${line}.dgtmp"  > /dev/null 2>&1
        fi
    done
}

#复制文件 ${1}: 目标module  ${2}: 应用的名字
function app_name() {
    dlog "app_name |${1},${2}"
    file_path="${PROJECT_MIRRORING}/${1}/src/main/res/values/strings.xml"
    manifest="src/main/AndroidManifest.xml"
    match_file ${1} ${manifest} "\@string\/app_name" "${2}"
}

#复制文件 ${1}: 目标module  ${2}: 源文件相对路径 ${3}: 目标文件相对路径
function copy_file() {
    dlog "copy_file |${1},${2},${3}|"
    src_file_path="${METADATD_DIR}/${1}/${2}"
    target_file_path="${PROJECT_MIRRORING}/${1}/${3}"

    dlog "copy_file src_file_path: ${src_file_path}"
    if [ ! -f ${src_file_path} ];then
        log "--Warn file not found!!  ${src_file_path}"
        exit 1
    fi
    dlog "copy_file target_file_path: ${target_file_path}"
    cp ${src_file_path} ${target_file_path}
}

#替换指定行内容
function replace_line() {
    dlog "replace_line |${1},${2},${3},${4}|"

    file_path="${PROJECT_MIRRORING}/${1}/${2}"
    dlog "replace_line file_path: ${file_path}"
    sed -i.dgtmp "${3}s/.*/${4}/" ${file_path}
    rm "${file_path}.dgtmp" > /dev/null 2>&1
}

#替换单体文件中的内容 ${1}: 目标module  ${2}: 目标文件相对路径 ${3}: 被替换的内容 ${4}: 目标内容
function match_file() {
    target=${1}
    target_file=${2}

    src_str=${3}
    dest_str=${4}
    dlog "match_file target: ${1},target_file: ${target_file},src_str: ${src_str},dest_str: ${dest_str}"

    file_path="${PROJECT_MIRRORING}/${target}/${target_file}"
    sed -i.dgtmp "s/${src_str}/${dest_str}/g" ${file_path}
    rm "${file_path}.dgtmp" > /dev/null 2>&1
}

#替换项目包名
function package() {
    target=${1}
    src_project=${2}
    package_name=${3}

    #目标工程路径
    target_dir="${PROJECT_MIRRORING}/${target}"
    manifest="src/main/AndroidManifest.xml"

    old_package_name=$(cat ${target_dir}/${manifest} | grep "package=\"")
    old_package_name=${old_package_name/package=\"/}
    old_package_name=${old_package_name/\"}
    old_package_name=$(echo ${old_package_name} | sed -e 's/\(^ *\)//' -e 's/\( *$\)//')

    log "rename $target package ${old_package_name} to $package_name"

    match_file ${target} "build.gradle" ${old_package_name} ${package_name}
    match_file ${target} ${manifest} "package=\"${old_package_name}\"" "package=\"${package_name}\""
    match_all ${target} "src/main/java" "${old_package_name}.R" "${package_name}.R"

    search_path="${PROJECT_MIRRORING}/${1}/src/main/java"
    dlog "search_path: ${search_path}"

    #为所有的
    find ${search_path} -name '*.java' | while read line
    do
        src_str=$(cat ${line} | grep 'package')
        dest_str="${src_str}import ${package_name}.R;"

        sed -i.dgtmp "s/${src_str}/${dest_str}/g" ${line} > /dev/null 2>&1
        rm "${line}.dgtmp" > /dev/null 2>&1
    done
}

#插件函数===end

#生成target  ${1}: 目标名字  ${2}: 源项目
function generate_target() {
    dlog "generate_target |${1},${2}|"
    target=${1}
    src_project=${2}
    #dlog "target: $target , src_project: $src_project"
    #复制一个以target命名的新项目，以src_project为蓝本
    dlog "cp  ${PROJECT_MIRRORING}/${src_project}   to  ${PROJECT_MIRRORING}/${target}"
    cp -r "${PROJECT_MIRRORING}/${src_project}" "${PROJECT_MIRRORING}/${target}"
    #把新的工程配置添加到settings.gradle
    echo "include ':${target}'" >> "${PROJECT_MIRRORING}/settings.gradle"

    #判断dsl文件是否存在
    config_file="${METADATD_DIR}/${target}/${DSL_FILE_NAME}"
    if [ ! -f $config_file ];then
        log "--Warn config file: 'metadata.dsl' not found   ${config_file}"
        exit 1;
    fi

    #解析并执行描述文件
    #获取配置的包名
    package_name=$(cat "$config_file"| grep 'package' | awk '{print $2}')
    package_name=${package_name:="com.example.${target}"}
    dlog "==package: ${package_name}"
    package $target $src_project $package_name

    cat $config_file | while read line
    do
        line=$(echo $line)
        if [ "$line" != "" ] && [ "${line:0:1}" != '#' ];then
            action=$(echo $line | awk '{print $1}')
            if [ "$action" != "package" ];then
                #调用动作对应的c函数并传参
                dlog "《《《 ${line/$action/$target}"
                "$action" ${target} $(echo $line | awk '{print $2}') $(echo $line | awk '{print $3}') $(echo $line | awk '{print $4}') $(echo $line | awk '{print $5}')
            fi
        fi
    done
}

#打印调试日志
function dlog() {
    if [ ${DEBUG} != 0 ];then
         echo $1
    fi
}

function log() {
    if [ ${DEBUG} == 0 ];then
         echo $1
    fi
}

#清理临时文件
function cleanup() {
    rm -rf $WORK_DIR
    rm -rf ${TARGET_APK_DIR}
    rm -rf "${PROJECT_DIR}/build"
    rm -rf "${PROJECT_DIR}/colze/build"
    rm -rf "${PROJECT_DIR}/comprehension/build"
}

function init_context() {
    #生成镜像工程目录
    mkdir -p "$WORK_DIR/${PROJECT_NAME}"

    log "Copying project .... "
    #创建工程镜像
    cp -r ${PROJECT_DIR} $WORK_DIR
}

dlog "work dir: ${WORK_DIR}"

cleanup
init_context

TARGET_ARRAY=()
index=1;
#扫描需要生成的任务
for file in $(ls $METADATD_DIR)
  do
   if [ -d "$METADATD_DIR/$file" ]  && [ $file != 'out' ] ;then
        #判断是否是有效的模版template(以colze-  或者  comprehension-开头)
        if [[ $file =~ ^colze_|^comprehension_ ]];then
            #dlog "$METADATD_DIR/$file"
            TARGET_ARRAY[$index]=$file
            index=$((index + 1))
        else
            log "--Warn Invalid template: '$file'.   Must begin with 'cloze-' or 'comprehension-'"
            exit 1
        fi
   fi
done

#执行任务，生成源代码
for target in ${TARGET_ARRAY[@]}
do
    generate_target $target ${target%_*}
done

rm -rf ${TARGET_APK_DIR}

#打包apk
for target in ${TARGET_ARRAY[@]}
do
    cd ${PROJECT_MIRRORING}/${target}
    gradle clean build
    if [ $? == 0 ];then
        if [ ! -d ${TARGET_APK_DIR} ];then
            mkdir -p ${TARGET_APK_DIR}
        fi
        cp "${PROJECT_MIRRORING}/${target}/build/outputs/apk/${target}-debug.apk" "${TARGET_APK_DIR}/${target}.apk"
        log "《《《 genarate apk success ${TARGET_APK_DIR}/${target}.apk"
    else
        log "《《《 genarate apk fail !!!!"
    fi
done

cd ${PWD}
