#!/bin/sh
export PATH="`pwd`:${PATH}"

#下载Adblock规则
function download_link(){
local IFS=$'\n'

target_dir="${1}"
test "${target_dir}" = "" && target_dir="`pwd`/temple/download_Rules"
mkdir -p "${target_dir}"

list='
https://ublockorigin.github.io/uAssets/filters/unbreak.txt|Ublock_unbreak.txt
https://ublockorigin.github.io/uAssets/filters/quick-fixes.txt|Ublock_fix.txt
https://ublockorigin.github.io/uAssets/filters/badware.txt|Ublock_badware.txt
https://ublockorigin.github.io/uAssets/filters/privacy.min.txt|Ublock_privacy.txt
https://ublockorigin.github.io/uAssets/filters/filters.min.txt|Ublock.txt
'

for i in ${list}
do
test "$(echo "${i}" | grep -E '^#' )" && continue
	name=`echo "${i}" | cut -d '|' -f2`
		URL=`echo "${i}" | cut -d '|' -f1`
	if test ! -f "${target_dir}/${name}" ;then
		curl -k -L -o "${target_dir}/${name}" "${URL}" >/dev/null 2>&1
	else
		echo "※ `date +'%F %T'` ${name} 下载成功！"
	fi
busybox sed -i 's/\\n/换行符正则表达式nn/g' "${target_dir}/${name}"
dos2unix "${target_dir}/${name}" >/dev/null 2>&1
done
}

#写入基本信息
function write_head(){
local file="${1}"
local Description="${3}"
test "${Description}" = "" && Description="${2}"
local count=`cat "${file}" | busybox sed '/^!/d;/^[[:space:]]*$/d' | wc -l ` 
local original_file=`cat "${file}"`
cat << key > "${file}"
[Adblock Plus 2.0]
! Title: ${2}
! Version: `date +'%Y%m%d%H%M%S'`
! Expires: 12 hours (update frequency)
! Last modified: `date +'%F %T'`
! Total Count: ${count}
! Blocked Filters: ${count}
! Description: ${Description}
! Homepage: https://github.com/lingeringsound/Ublock_filter_for_via
! Github Raw Link: https://raw.githubusercontent.com/lingeringsound/Ublock_filter_for_via/main/${file##*/}

key
echo "${original_file}" >> "${file}"
busybox sed -i 's/换行符正则表达式n/\\/g' "${file}"
perl "`pwd`/addchecksum.pl" "${file}"
}

#净化规则
function modtify_adblock_original_file() {
local file="${1}"
if test "${2}" = "" ;then
	busybox sed -i 's/\\n/换行符正则表达式nn/g' "${file}"
	local new=`cat "${file}" | iconv -t 'utf8' | grep -Ev '^#\@\?#|^\$\@\$|^#\%#|^#\@\%#|^#\@\$\?#|^#\$\?#|^<<|<<1023<<' | busybox sed 's|^[[:space:]]@@|@@|g' | sort | uniq | busybox sed -E 's/^[[:space:]]+//g' | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' `
	echo "$new" > "${file}"
else
	busybox sed -i 's/\\n/换行符正则表达式nn/g' "${file}"
	local new=`cat "${file}" | iconv -t 'utf8' | grep -Ev '^#\@\?#|^\$\@\$|^#\%#|^#\@\%#|^#\@\$\?#|^#\$\?#|^<<|<<1023<<' | grep -Ev "${2}" | busybox sed 's|^[[:space:]]@@|@@|g' | sort | uniq | busybox sed -E 's/^[[:space:]]+//g' | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' `
	echo "$new" > "${file}"
fi

}

function make_white_rules(){
local file="${1}"
local IFS=$'\n'
local white_list_file="${2}"
for o in `cat "${white_list_file}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' `
do
busybox sed -i -E "/${o}/d" "${file}"
done
}

function fix_Rules(){
local file="${1}"
local target_content="${2}"
local fix_content="${3}"
test ! -f "${file}" -o "${fix_content}" = "" && return 
busybox sed -i "s|${target_content}|${fix_content}|g" "${file}"
}

function Combine_adblock_original_file(){
local file="${1}"
local target_folder="${2}"
test "${target_folder}" = "" && echo "※`date +'%F %T'` 请指定合并目录……" && exit
for i in "${target_folder}"/*.txt
do
	dos2unix "${i}" >/dev/null 2>&1
	echo "`cat "${i}"`" >> "${file}"
done
}

#shell 特殊字符转义
function escape_special_chars(){
	local input=${1}
	local output=$(echo ${input} | busybox sed 's/[\^\|\*\?\$\=\@\/\.\"\+\;\(\)\{\}]/\\&/g;s|\[|\\&|g;s|\]|\\&|g' )
	echo ${output}
}

#去除指定重复的Css
function sort_Css_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`cat "${target_file}" | grep '#'  | busybox sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | busybox sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d | wc -l`
local a=0
busybox sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(cat "${target_file}" | iconv -t 'utf-8' | sort -u | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
echo "${new_file}" > "${target_file}"
for target_content in `cat "${target_file}" | grep '#'  | busybox sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | busybox sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d `
do
a=$(($a + 1))
target_content="#${target_content}"
transfer_content=$(escape_special_chars ${target_content})
grep -E "${transfer_content}$" "${target_file}" > "${target_file_tmp}" && echo "※处理重复Css规则( $count_Rules_all → $(($count_Rules_all - ${a})) ): ${transfer_content}$"
if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed 's|#.*||g' | grep -E ',')" != "" ;then
	busybox sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr ',' '\n' | busybox sed '/^[[:space:]]*$/d' | sort  | uniq )
	echo "${before_tmp}" > "${target_file_tmp}"
	busybox sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "${transfer_content}$" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	busybox sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | busybox sed '/^[[:space:]]*$/d' | sort | uniq)
	echo "${before_tmp}" > "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' | wc -l)" -gt "1" ;then
		busybox sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	fi
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "${transfer_content}$" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
rm -rf "${target_file_tmp}" 2>/dev/null
}

#去除重复作用的域名
function sort_domain_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`cat "${target_file}" | busybox sed 's|domain=.*||g' | sort | uniq -d | busybox sed '/^[[:space:]]*$/d' | wc -l `
local a=0
busybox sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(cat "${target_file}" | iconv -t 'utf-8' | sort -u | uniq | busybox sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
echo "${new_file}" > "${target_file}"
for target_content in `cat "${target_file}" | grep 'domain=' | busybox sed 's|domain=.*||g' | sort | uniq -d | busybox sed '/^[[:space:]]*$/d' `
do
a=$(($a + 1))
target_content="${target_content}domain="
transfer_content=$(escape_special_chars ${target_content} )
grep -E "^${transfer_content}" "${target_file}" > "${target_file_tmp}" && echo "※处理重复作用域名规则( $count_Rules_all → $(($count_Rules_all - ${a} )) ): ^${transfer_content}"
if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed 's|.*domain=||g' | grep -E ',' )" != "" ;then
	echo "※规则 ${target_content} 包含其他限定器！"
	local fixed_tmp=$(cat "${target_file_tmp}" | busybox sed 's/[[:space:]]$//g' | grep -Ev ',(important|third-party|script|media|subdocument|document|xmlhttprequest|other|stealth|image|stylesheet|content|match-case|font|sitekey|popup|xhr|object|generichide|genericblock|elemhide|all|badfilter|websocket|~important|~third-party|~script|~media|~subdocument|~document|~xmlhttprequest|~other|~stealth|~image|~stylesheet|~content|~match-case|~font|~sitekey|~popup|~xhr|~object|~generichide|~genericblock|~elemhide|~all|~badfilter|~websocket)$' | busybox sed '/^[[:space:]]*$/d' | sort | uniq)
	echo "${fixed_tmp}" > "${target_file_tmp}"
	echo "※尝试修复中……"
	local Rules_juggle=`cat "${target_file_tmp}" | sort | uniq | busybox sed '/^[[:space:]]*$/d' | wc -l`
	test "${Rules_juggle}" -le "1" && echo "※无法合并，已跳过！" && continue
fi
if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed 's|.*domain=||g' | grep -E '\|')" != "" ;then
	busybox sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr '|' '\n' | busybox sed '/^[[:space:]]*$/d' | sort  | uniq)
	echo "${before_tmp}" > "${target_file_tmp}"
	busybox sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	busybox sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | busybox sed '/^[[:space:]]*$/d' | sort  | uniq)
	echo "${before_tmp}" > "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' | wc -l)" -gt "1" ;then
		busybox sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	fi
	if test "$(cat "${target_file_tmp}" 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}"
cat << key >> "${target_output_file}" 
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
rm -rf "${target_file_tmp}" 2>/dev/null
busybox sed -i 's/换行符正则表达式n/\\/g' "${target_file}"
}

#避免大量字符影响观看
function Running_sort_domain_Combine(){
local IFS=$'\n'
local target_adblock_file="${1}"
test ! -f "${target_adblock_file}" && echo "※`date +'%F %T'` ${target_adblock_file} 规则文件不存在！！！" && return
sort_domain_Combine "${target_adblock_file}"
modtify_adblock_original_file "${target_adblock_file}"
wipe_same_selector_fiter "${target_adblock_file}"
modtify_adblock_original_file "${target_adblock_file}"
clear_domain_white_list "${target_adblock_file}"
modtify_adblock_original_file "${target_adblock_file}"
clear_domain_white_Rules "${target_adblock_file}"
}


#避免大量字符影响观看
function Running_sort_Css_Combine(){
local target_adblock_file="${1}"
test ! -f "${target_adblock_file}" && echo "※`date +'%F %T'` ${target_adblock_file} 规则文件不存在！！！" && return
#记录通用的Css
local css_common_record="$(cat ${target_adblock_file} 2>/dev/null | busybox sed '/^!/d;/^[[:space:]]*$/d' | grep -E '^#' )"
sort_Css_Combine "${target_adblock_file}"
#写入通用的Css
echo "${css_common_record}" >> "${target_adblock_file}"
busybox sed -i 's/换行符正则表达式n/\\/g' "${target_adblock_file}"
}

#规则分类
function sort_and_optimum_adblock(){
local file="${1}"
test ! -f "${file}" && return 
cat << key > "${file}"

!<<<<<域名规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\|\||^\|http' | sort | uniq | wc -l `
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\|\||^\|http' | sort | uniq `
!<<<<<域名规则 结束>>>>>

!<<<<<网站单独规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort | uniq | wc -l`
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort | uniq `
!<<<<<网站单独规则 结束>>>>>

!<<<<<通配符规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort | uniq | wc -l `
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort | uniq `
!<<<<<通配符规则 结束>>>>>

!<<<<<通用Css规则>>>>>`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^#|^~.*#' | sort | uniq | wc -l`
`cat "${file}" | busybox sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^#|^~.*#' | sort | uniq `
!<<<<<通用Css规则 结束>>>>>

!<<<<<放行白名单>>>>>`cat "${file}" | busybox sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\@\@|#\@#' | sort | uniq | wc -l`
`cat "${file}" | busybox sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\@\@|#\@#' | sort | uniq `
!<<<<<放行白名单 结束>>>>>

key
}

#剔除css规则冲突规则
function fixed_css_white_conflict(){
local file="${1}"
local white_list=`cat ${file} | grep -E '^#\@#' | busybox sed -E 's/#\@#/##/g' `
for i in ${white_list}
do
	echo "剔除冲突规则 ${i}"
	rule=`escape_special_chars ${i}`
	busybox sed -i -E "/^${rule}$/d" "${file}"
done
}

#去除部分选择器
function wipe_same_selector_fiter(){
local file="${1}"
local IFS=$'\n'
test ! -f "${file}" && return
local target_domain_list="$(grep -E '^\|\|' "${file}" | busybox sed -E 's/\$third-party$//g;s/\$popup$//g;s/\$third-party,important$//g;s/\$popup,third-party$//g;s/\$third-party,popup$//g;s/\$script$//g;s/\$image$//g;s/\$image,third-party$//g;s/\$third-party,image$//g;s/\$script,third-party$//g;s/\$third-party,script$//g;/domain=/d;/^!/d;/^[[:space:]]*$/d' | sort | uniq -d)"
local target_domain_list_count_all=$(echo "$target_domain_list" | wc -l)
local a=0
for i in $target_domain_list; do
	End_target=$((${target_domain_list_count_all} - $a))
	a=$(($a + 1))
	same_fiter_rule=$(escape_special_chars "${i}")
	busybox sed -i -E "/^${same_fiter_rule}\\$/d" "${file}"
	echo "※去除域名规则(${target_domain_list_count_all} → ${End_target}) ${i}"
done
}

#去除重复的域名规则
function clear_domain_white_list(){
local file="${1}"
test ! -f "${file}" && return
cat "${file}" | busybox sed '/^\!/d;/\#/d;/\$/d' | grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]{1,5})?(/[^ ]*)?' | sort -u | while read line
do
	transfer_content=`escape_special_chars ${line}`
	grep -E "^\|\|${transfer_content}\^" "${file}" && busybox sed -i -E "/^${transfer_content}$/d" "${file}"
done
}

#去除与白名单冲突的域名
function clear_domain_white_Rules(){
local file="${1}"
test ! -f "${file}" && return
cat "${file}" | grep -E 'domain=~' | busybox sed '/#/d;s/\$.*//g' | while read line
do
	transfer_Rules=`escape_special_chars ${line}`
	busybox sed -i -E "/^${transfer_Rules}$/d" "${file}"
done
}

#修复低级错误
function fixed_Rules_error(){
	local file="${1}"
	test ! -f "${file}" && return
	sed -i -E -e '/\$app=/d' \
	-e 's/=“/=\"/g' \
	-e 's/^[[:space:][:cntrl:]]//g' \
	-e 's/\*=“/\*=\"/g' \
	-e 's/\^=“/\^=\"/g' \
	-e 's/\$=“/\$=\"/g' \
	-e 's/”\]/\"\]/g' \
	-e 's/\]\]/\]/g' \
	-e 's/\[\[/\[/g' \
	-e 's/([^#])[[:cntrl:][:space:]./$]##/\1##/g' \
	-e 's/([^#])##[[:cntrl:][:space:]/$]/\1##/g' \
	-e 's/###[[:cntrl:][:space:].#/$]/###/g' \
	-e 's/##([[:digit:]]+)/##\\\1/g' \
	-e 's/##\.\[/##\[/g' \
	-e 's/^##[[:cntrl:][:space:]/$]/##/g' \
	-e 's/[[:space:]]\|/\|/g' \
	-e 's/\|[[:space:]]/\|/g' \
	-e 's/([^:])\:(after|before)/\1\:\:\2/g' "${file}"
#sed -i -E -e 's/(\[[:alpha:]|[\*\^\$])=([^"]*)(\])/\1="\2"\3/g' \
#	-e 's/(\[[:alpha:]|[\*\^\$]=\")([^"]*)\]/\1\2\"\]/g' \
#	-e 's/(\[[:alpha:]|[\*\^\$])=([^"]*)(\"\])/\1="\2\3/g' "${file}"
	gawk -i inplace '{ while (match($0, /^##[A-Z]+\[/)) { $0 = substr($0, 1, RSTART-1) tolower(substr($0, RSTART, RLENGTH)) substr($0, RSTART+RLENGTH) } print }' "${file}"
}

#去除badfilter对应规则
function wipe_badfilter(){
local file="${1}"
test ! -f "${file}" && return 0
grep -E '(\$|\,)badfilter' "${file}" | while read fitter
do
	select_after=$(echo ${fitter} | busybox sed -E 's/\,badfilter$//g;s/\,badfilter\,/\,/g;s/\$badfilter//g')
	selector=$(escape_special_chars ${select_after})
	busybox sed -i -E "/^${selector}$/d" "${file}"
done
}

#转换成原生has规则
function add_has_fiter(){
local file="${1}"
local target_folder="${2}"
local target_website="${3}"
test ! -f "${file}" -o ! -d "${target_folder}" && return
if test "${target_website}" = "" ;then
	local has_fiter="$(grep -E ':-abp-has|:has' "${file}" | grep -Ev ":-abp-contains|:-abp-properties|:contains|:has-text|:matches-attr|:matches-css|:matches-css-after|:matches-css-before|:matches-path|:matches-property|:min-text-length|:nth-ancestor|:remove|:style|:upward|:watch-attr|:xpath|[[:space:]]{[[:space:]]remove:[[:space:]]true;[[:space:]]}|^#|^\!|^\[|\*#" | sed 's/\#\?\#/\#\#/g;s/:-abp-has/:has/g' | sort | uniq )"
else
	local has_fiter="$(grep -E ':-abp-has|:has' "${file}" | grep -E "${target_website}" | grep -Ev ":-abp-contains|:-abp-properties|:contains|:has-text|:matches-attr|:matches-css|:matches-css-after|:matches-css-before|:matches-path|:matches-property|:min-text-length|:nth-ancestor|:remove|:style|:upward|:watch-attr|:xpath|[[:space:]]{[[:space:]]remove:[[:space:]]true;[[:space:]]}|^#|^\!|^\[|\*#" | sed 's/\#\?\#/\#\#/g;s/:-abp-has/:has/g' | sort | uniq )"
fi
echo "${has_fiter}" > "${target_folder}/${file##*/}_has.txt"
}

#转换Ublock规则到via
function Ublock_to_adblock(){
local target_file="${1}"
test ! -f "${target_file}" && return 0
local transfer_file="$(grep -Ev '#\@\?#|\$\@\$|#\%#|#\@\%#|#\@\$\?#|#\$\?#|#\$#|#\?#|##\^|#\+js\(|#\%#\/\/scriptlet|redirect=|\,replace=|\$replace=|\$urlskip=|\,urlskip=|\$uritransform=|\,uritransform=|redirect-rule=|to=|^/(\^|\\|\[|\(\?)|^\*\$|\$badfilter|\$cname|\$css|\$empty|\$frame|\$generichide|\$ghide|\$match-case|\$media|\$object|\$object-subrequest|\$ping|\$popunder|\$popup|\$~badfilter|\$~cname|\$~css|\$~empty|\$~frame|\$~generichide|\$~ghide|\$~match-case|\$~media|\$~object|\$~object-subrequest|\$~ping|\$~popunder|\$~popup|\,badfilter$|\,badfilter\,|\,cname$|\,cname\,|\,css$|\,css\,|\,empty$|\,empty\,|\,frame$|\,frame\,|\,generichide$|\,generichide\,|\,ghide$|\,ghide\,|\,match-case$|\,match-case\,|\,media$|\,media\,|\,object$|\,object-subrequest$|\,object-subrequest\,|\,object\,|\,ping$|\,ping\,|\,popunder$|\,popunder\,|\,popup$|\,popup\,|\,~badfilter$|\,~badfilter\,|\,~cname$|\,~cname\,|\,~css$|\,~css\,|\,~empty$|\,~empty\,|\,~frame$|\,~frame\,|\,~generichide$|\,~generichide\,|\,~ghide$|\,~ghide\,|\,~match-case$|\,~match-case\,|\,~media$|\,~media\,|\,~object$|\,~object-subrequest$|\,~object-subrequest\,|\,~object\,|\,~ping$|\,~ping\,|\,~popunder$|\,~popunder\,|\,~popup$|\,~popup\,|\$csp|\,csp=|\,denyallow=|permissions=|removeparam=|\:matches-path|:remove\(\)|:-abp-contains|:-abp-properties|:contains|:has-text|:matches-attr|:matches-css|:matches-css-after|:matches-css-before|:matches-path|:matches-property|:min-text-length|:nth-ancestor|:remove|:style|:upward|:watch-attr|:xpath' "${target_file}" | busybox sed -e '/^\!/d;/^[[:space:]]*$/d' \
 -e 's/\$3p/\$third-party/g' \
 -e 's/\$1p/\$~third-party/g' \
 -e 's/\$~3p/\$~third-party/g' \
 -e 's/\$~1p/\$third-party/g' \
 -e 's/\,1p$/\,~third-party/g' \
 -e 's/\,1p\,/\,~third-party\,/g' \
 -e 's/\,3p$/\,third-party/g' \
 -e 's/\,3p\,/\,third-party\,/g' \
 -e 's/\,~1p$/\,third-party/g' \
 -e 's/\,~1p\,/\,third-party\,/g' \
 -e 's/\,~3p$/\,~third-party/g' \
 -e 's/\,~3p\,/\,~third-party\,/g' \
 -e 's/\,strict3p/\,third-party/g' \
 -e 's/\$strict3p/\$third-party/g' \
 -e 's/\$xhr/\$xmlhttprequest/g' \
 -e 's/\$~xhr/\$~xmlhttprequest/g' \
 -e 's/\,xhr\,/\,xmlhttprequest\,/g' \
 -e 's/\,xhr$/\,xmlhttprequest/g' \
 -e 's/\,~xhr\,/\,~xmlhttprequest\,/g' \
 -e 's/\,~xhr$/\,~xmlhttprequest/g' \
 -e 's/\$important$//g' \
 -e 's/\$important,/\$/g' \
 -e 's/\,important\,/\,/g' \
 -e 's/\,important$//g' \
 -e 's/\$~important$//g' \
 -e 's/\$~important,/\$/g' \
 -e 's/\,~important\,/\,/g' \
 -e 's/\,~important$//g' \
 -e 's/\$all$//g' \
 -e 's/\$all,/\$/g' \
 -e 's/\,all\,//g' \
 -e 's/\,all$//g' \
 -e 's/\$~all$//g' \
 -e 's/\$~all,/\$/g' \
 -e 's/\,~all\,//g' \
 -e 's/\,~all$//g' \
 -e 's/\$doc$//g' \
 -e 's/\$doc,/\$/g' \
 -e 's/\,doc\,//g' \
 -e 's/\,doc$//g' \
 -e 's/\$~doc$//g' \
 -e 's/\$~doc,/\$/g' \
 -e 's/\,~doc\,//g' \
 -e 's/\,~doc$//g' | sort | uniq)"
 echo "${transfer_file}" > "${target_file}"
}


#更新README信息
function update_README_info(){
local file="`pwd`/README.md"
test -f "${file}" && rm -rf "${file}"
cat << key > "${file}"
# Ublock filter for Via
> (`date +'%F %T'`)
> 将Ublock规则转为Via可用的规则，每12小时更新一次。

### 订阅规则
- Raw原链接
\`\`\`
https://raw.githubusercontent.com/lingeringsound/Ublock_filter_for_via/refs/heads/main/Ublock_filter_for_via.txt
\`\`\`
- 镜像链接
\`\`\`
https://raw.gitmirror.com/lingeringsound/Ublock_filter_for_via/main/Ublock_filter_for_via.txt
\`\`\`

### 上游规则
#### 感谢各位大佬❤ (ɔˆз(ˆ⌣ˆc)
- [ublockorigin.github.io](https://ublockorigin.github.io/uAssets)
key
}

update_README_info



