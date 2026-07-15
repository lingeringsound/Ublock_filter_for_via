#!/bin/sh

#加载公共函数
source "`pwd`/until_function.sh"

#指定目录和输出文件
Download_Folder="`pwd`/temple/download_Rules"

#删除缓存?(也许)
rm -rf "`pwd`/temple" 2>/dev/null

#创建目录
mkdir -p "${Download_Folder}" && echo "※`date +'%F %T'` 创建临时目录成功！"

#设置权限
chmod -R 777 "`pwd`"

#下载规则
download_link "${Download_Folder}"

# Ublock for via
#预处理规则
Combine_adblock_original_file "`pwd`/Ublock_filter_for_via.txt" "${Download_Folder}"
#去除badfilter
wipe_badfilter "`pwd`/Ublock_filter_for_via.txt"
#转换via规则
Ublock_to_adblock "`pwd`/Ublock_filter_for_via.txt"
#净化去重规则
modtify_adblock_original_file "`pwd`/Ublock_filter_for_via.txt"
#剔除冲突的CSS规则
fixed_css_white_conflict "`pwd`/Ublock_filter_for_via.txt"
#去除重复作用域名
Running_sort_domain_Combine "`pwd`/Ublock_filter_for_via.txt"
#去除指定重复的Css
Running_sort_Css_Combine "`pwd`/Ublock_filter_for_via.txt"
#修复低级错误
fixed_Rules_error "`pwd`/Ublock_filter_for_via.txt"
#再次净化去重
modtify_adblock_original_file "`pwd`/Ublock_filter_for_via.txt"
#规则分类
sort_and_optimum_adblock "`pwd`/Ublock_filter_for_via.txt"
#写入头信息
write_head "`pwd`/Ublock_filter_for_via.txt" "Ublock filter for Via(`date '+%F %T'`)" "合并Ublock自带的5个主规则，适用于移动端轻量的浏览器，例如 VIA" && echo "※`date +'%F %T'` Ublock filter for Via 合并完成！"

rm -rf "`pwd`/temple"
#更新README信息
update_README_info




