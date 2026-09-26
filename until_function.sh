#!/bin/sh
export PATH="`pwd`:${PATH}"

#使用magisk的busybox sed
#主要我本地规则用的就是magisk的busybox，GNU的sed -iE 在白名单方面有问题。
if command -v busybox >/dev/null 2>&1 ;then 
	sed() { busybox sed "${@}"; }
	awk() { busybox awk "${@}"; }
fi

#安全写入文件，避免转换\\ 和 Unicode字符
function write_notran_file() {
local content="${1}"
local file="${2}"
local flag="${3}"
[ -z "${file}" ] && return
[ -z "${flag}" ] && flag=">"
if [ "$(command -v printf)" = "printf" ]; then
	if [ "${flag}" = ">>" ]; then
		printf '%s\n' "${content}" >> "$file"
	else
		printf '%s\n' "${content}" > "$file"
	fi
elif [ "$(command -v print)" = "print" ]; then
	if [ "${flag}" = ">>" ]; then
		print -r -- "${content}" >> "$file"
	else
		print -r -- "${content}" > "$file"
	fi
else
	if [ "${flag}" = ">>" ]; then
cat >> "$file" << EOF
${content}
EOF
	else
cat > "$file" << EOF
${content}
EOF
	fi
fi
}

#转换文件为UTF-8编码
function convert_enc_to_UTF() {
local file="$1"
local output_file="${2:-$file}"
local python_file="`pwd`/convert_enc.py"
[ -f "$file" ] || return
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ]; then
	[ "${file}" = "${output_file}" ] && python3 "${python_file}" "${file}" || python3 "${python_file}" "${file}" "${output_file}"
else
	dos2unix "$file" >/dev/null 2>&1
fi
}

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
sed -i 's/\\n/换行符正则表达式nn/g' "${target_dir}/${name}"
convert_enc_to_UTF "${target_dir}/${name}"
done
}

#写入基本信息
function write_head(){
local file="${1}"
local Description="${3}"
test "${Description}" = "" && Description="${2}"
local count=`sed '/^!/d;/^[[:space:]]*$/d' "${file}" | wc -l ` 
local original_file=`cat "${file}"`
cat > "${file}" << key 
[Adblock Plus 2.0]
! Title: ${2}
! Version: `date +'%Y%m%d%H%M%S'`
! Expires: 12 hours (update frequency)
! Last modified: `date +'%F %T'`
! Human Count: $(count_filter_files "${count}")
! Blocked Filters: ${count}
! Description: ${Description}
! Homepage: https://github.com/lingeringsound/Ublock_filter_for_via
! Github Raw Link: https://raw.githubusercontent.com/lingeringsound/Ublock_filter_for_via/main/${file##*/}

${original_file}
key
sed -i 's/换行符正则表达式n/\\/g' "${file}"
local checksum_file="`pwd`/addchecksum.py"
if command -v python >/dev/null 2>&1 && [ -f "${checksum_file}" ]; then 
	python "${checksum_file}" "${file}"
elif command -v perl >/dev/null 2>&1 && [ -f "${checksum_file%%.*}.pl" ]; then
	perl "${checksum_file%%.*}.pl" "${file}"
fi
}

#净化规则
function modtify_adblock_original_file() {
local file="${1}"
local exclude_re='^#(@(\?|%|\$\?)#|(%|\$\?)#)|^\$@\$|^<<|<<1023<<'
local new
[ -f "$file" ] || return
sed -i 's/\\n/换行符正则表达式nn/g' "${file}"
if test "${2}" = "" ;then
	new=`grep -Ev "${exclude_re}" "${file}" | sed 's|^[[:space:]]@@|@@|g;/^!/d;/^\[.*\]$/d;/^[[:space:]]*$/d' | sort -u `
	write_notran_file "$new" "${file}"
else
	new=`grep -Ev "${exclude_re}|${2}" "${file}" | sed 's|^[[:space:]]@@|@@|g;/^!/d;/^\[.*\]$/d;/^[[:space:]]*$/d' | sort -u `
	write_notran_file "$new" "${file}"
fi
}

function make_white_rules(){
local file="${1}"
local IFS=$'\n'
local white_list_file="${2}"
for o in `cat "${white_list_file}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' `
do
sed -i -E "/${o}/d" "${file}"
done
}

function fix_Rules(){
local file="${1}"
local target_content="${2}"
local fix_content="${3}"
test ! -f "${file}" -o "${fix_content}" = "" && return 
sed -i "s|${target_content}|${fix_content}|g" "${file}"
}

function Combine_adblock_original_file(){
local file="${1}"
local target_folder="${2}"
test "${target_folder}" = "" && echo "※`date +'%F %T'` 请指定合并目录……" && exit
: > "${file}"
for i in "${target_folder}"/*.txt "${target_folder}"/*.prop
do
	[ -f "${i}" ] || continue
	dos2unix "${i}" >/dev/null 2>&1
	cat "${i}" >> "${file}"
done
}

#shell 特殊字符转义
function escape_special_chars(){
	local input=${1}
	local output=$(echo ${input} | sed 's/[\^\|\*\?\$\=\@\/\.\"\+\;\(\)\{\}]/\\&/g;s|\[|\\&|g;s|\]|\\&|g' )
	echo ${output}
}

#去除指定重复的Css
function sort_Css_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`cat "${target_file}" | grep '#'  | sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d | wc -l`
local a=0
sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(cat "${target_file}" | sort -u | uniq | sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
write_notran_file "${new_file}" "${target_file}"
for target_content in `cat "${target_file}" | grep '#'  | sed '/^#/d;/^!/d;/^\|\|/d;/^\//d' | sed -E 's/.*\.[A-Za-z]{2,8}#{1,1}//g' | sort | uniq -d `
do
a=$(($a + 1))
target_content="#${target_content}"
export T_STR="${target_content}"
awk '{str=ENVIRON["T_STR"]; if(index($0, str) && substr($0, length($0)-length(str)+1) == str) print $0}' "${target_file}" > "${target_file_tmp}" && echo "※处理重复Css规则( $count_Rules_all → $(($count_Rules_all - ${a})) ): ${target_content}"
if test "$(cat "${target_file_tmp}" 2>/dev/null | sed 's|#.*||g' | grep -E ',')" != "" ;then
	sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr ',' '\n' | sed '/^[[:space:]]*$/d' | sort  | uniq )
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then
		awk '{str=ENVIRON["T_STR"]; if(!(index($0, str) && substr($0, length($0)-length(str)+1) == str)) print $0}' "${target_file}" > "${target_output_file}"
cat << key >> "${target_output_file}" 
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	sed -i 's|#.*||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | sed '/^[[:space:]]*$/d' | sort -u )
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' | wc -l)" -gt "1" ;then
		sed -i ":a;N;\$!ba;s#\n#,#g" "${target_file_tmp}"
	fi
	if test "$(cat "${target_file_tmp}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then
		awk '{str=ENVIRON["T_STR"]; if(!(index($0, str) && substr($0, length($0)-length(str)+1) == str)) print $0}' "${target_file}" > "${target_output_file}"
cat << key >> "${target_output_file}" 
`cat "${target_file_tmp}"`${target_content}
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
unset T_STR
rm -rf "${target_file_tmp}" 2>/dev/null
}

#去除重复作用的域名
function sort_domain_Combine(){
local IFS=$'\n'
local target_file="${1}"
local target_file_tmp="`pwd`/${target_file##*/}.tmp"
local target_output_file="`pwd`/${target_file##*/}.temple"
local count_Rules_all=`cat "${target_file}" | sed 's|domain=.*||g' | sort | uniq -d | sed '/^[[:space:]]*$/d' | wc -l `
local a=0
sed -i 's/\\n/换行符正则表达式nn/g' "${target_file}"
local new_file=$(cat "${target_file}" | sort -u | uniq | sed '/^!/d;/^[[:space:]]*$/d;/^\[.*\]$/d' )
write_notran_file "${new_file}" "${target_file}"
for target_content in `cat "${target_file}" | grep 'domain=' | sed 's|domain=.*||g' | sort | uniq -d | sed '/^[[:space:]]*$/d' `
do
a=$(($a + 1))
target_content="${target_content}domain="
transfer_content=$(escape_special_chars ${target_content} )
grep -E "^${transfer_content}" "${target_file}" > "${target_file_tmp}" && echo "※处理重复作用域名规则( $count_Rules_all → $(($count_Rules_all - ${a} )) ): ^${transfer_content}"
if test "$(cat "${target_file_tmp}" 2>/dev/null | sed 's|.*domain=||g' | grep -E ',' )" != "" ;then
	echo "※规则 ${target_content} 包含其他限定器！"
	local fixed_tmp=$(cat "${target_file_tmp}" | sed 's/[[:space:]]$//g' | grep -Ev ',(important|third-party|script|media|subdocument|document|xmlhttprequest|other|stealth|image|stylesheet|content|match-case|font|sitekey|popup|xhr|object|generichide|genericblock|elemhide|all|badfilter|websocket|~important|~third-party|~script|~media|~subdocument|~document|~xmlhttprequest|~other|~stealth|~image|~stylesheet|~content|~match-case|~font|~sitekey|~popup|~xhr|~object|~generichide|~genericblock|~elemhide|~all|~badfilter|~websocket)$' | sed '/^[[:space:]]*$/d' | sort -u )
	write_notran_file "${fixed_tmp}" "${target_file_tmp}"
	echo "※尝试修复中……"
	local Rules_juggle=`cat "${target_file_tmp}" | sort -u | sed '/^[[:space:]]*$/d' | wc -l`
	test "${Rules_juggle}" -le "1" && echo "※无法合并，已跳过！" && continue
fi
if test "$(cat "${target_file_tmp}" 2>/dev/null | sed 's|.*domain=||g' | grep -E '\|')" != "" ;then
	sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | tr '|' '\n' | sed '/^[[:space:]]*$/d' | sort  | uniq)
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}" 
cat << key >> "${target_output_file}" 
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
else
	sed -i 's|.*domain=||g' "${target_file_tmp}"
	local before_tmp=$(cat "${target_file_tmp}" | sed '/^[[:space:]]*$/d' | sort  | uniq)
	write_notran_file "${before_tmp}" "${target_file_tmp}"
	if test "$(cat "${target_file_tmp}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' | wc -l)" -gt "1" ;then
		sed -i ":a;N;\$!ba;s#\n#\|#g" "${target_file_tmp}"
	fi
	if test "$(cat "${target_file_tmp}" 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' )" != "" ;then 
		grep -Ev "^${transfer_content}" "${target_file}" >> "${target_output_file}"
cat << key >> "${target_output_file}" 
${target_content}`cat "${target_file_tmp}"`
key
		mv -f "${target_output_file}" "${target_file}"
	fi
fi
done
rm -rf "${target_file_tmp}" 2>/dev/null
sed -i 's/换行符正则表达式n/\\/g' "${target_file}"
}

#去重函数python版
function sort_Css_Combine_python() {
local target_file="${1}"
local python_file="`pwd`/Adblock_sort.py"
if [ -f "$target_file" ] && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "css" "$target_file"
else
	sort_Css_Combine "$target_file"
fi
}

function sort_domain_Combine_python() {
local target_file="${1}"
local python_file="`pwd`/Adblock_sort.py"
if [ -f "$target_file" ] && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "domain" "$target_file"
else
	sort_domain_Combine "$target_file"
fi
}

#避免大量字符影响观看
function Running_sort_domain_Combine(){
local IFS=$'\n'
local target_adblock_file="${1}"
test ! -f "${target_adblock_file}" && echo "※`date +'%F %T'` ${target_adblock_file} 规则文件不存在！！！" && return
sort_domain_Combine_python "${target_adblock_file}"
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
#local css_common_record="$(cat ${target_adblock_file} 2>/dev/null | sed '/^!/d;/^[[:space:]]*$/d' | grep -E '^#' )"
sort_Css_Combine_python "${target_adblock_file}"
#写入通用的Css
#write_notran_file "${css_common_record}" "${target_adblock_file}" ">>"
sed -i 's/换行符正则表达式n/\\/g' "${target_adblock_file}"
fixed_css_selector_not_clean "${target_adblock_file}"
}

#规则分类
function sort_and_optimum_adblock_shell(){
local file="${1}"
test ! -f "${file}" && return 
cat << key > "${file}"

!<<<<<通配符规则>>>>>`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort -u | wc -l `
`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\|\||^\|http|##|#\?#|#\%#|#\@#|##\[|##\.|[#][$][#]|[#][$][?][#]|[#][@][?][#]|^#' | sort -u `
!<<<<<通配符规则 结束>>>>>

!<<<<<域名规则>>>>>`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\|\||^\|http' | sort -u | wc -l `
`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\|\||^\|http' | sort -u `
!<<<<<域名规则 结束>>>>>

!<<<<<网站单独规则>>>>>`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort -u | wc -l`
`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -Ev '^\@\@|^\|\||^\|http|^#|^\/|^:\/\/|^_|^\?|^\.|^-|^=|^:|^~|^,|^&|^\$|^\||^\*' | sort -u `
!<<<<<网站单独规则 结束>>>>>

!<<<<<通用Css规则>>>>>`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^#|^~.*#' | sort -u | wc -l`
`cat "${file}" | sed '/^!/d;/^\@\@/d;/#\@#/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^#|^~.*#' | sort -u `
!<<<<<通用Css规则 结束>>>>>

!<<<<<放行白名单>>>>>`cat "${file}" | sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\@\@|#\@#' | sort -u | wc -l`
`cat "${file}" | sed '/^!/d;/^\[/d;/^[[:space:]]*$/d' | grep -E '^\@\@|#\@#' | sort -u `
!<<<<<放行白名单 结束>>>>>

key
}

function sort_and_optimum_adblock() {
local file="${1}"
test ! -f "${file}" && return 
local python_file="`pwd`/sort_and_optimum_adblock.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "$file"
else
	sort_and_optimum_adblock_shell "$file"
fi
}

#剔除css规则冲突规则
function fixed_css_white_conflict_shell(){
local file="${1}"
local white_list=`cat ${file} | grep -E '^#\@#' | sed -E 's/#\@#/##/g' `
for i in ${white_list}
do
	echo "剔除冲突规则 ${i}"
	rule=`escape_special_chars ${i}`
	sed -i -E "/^${rule}$/d" "${file}"
done
}

#去除部分选择器
function wipe_same_selector_fiter_shell(){
local file="${1}"
local IFS=$'\n'
test ! -f "${file}" && return
local target_domain_list="$(grep -E '^\|\|' "${file}" | sed -E 's/\$third-party$//g;s/\$popup$//g;s/\$third-party,important$//g;s/\$popup,third-party$//g;s/\$third-party,popup$//g;s/\$script$//g;s/\$image$//g;s/\$image,third-party$//g;s/\$third-party,image$//g;s/\$script,third-party$//g;s/\$third-party,script$//g;/domain=/d;/^!/d;/^[[:space:]]*$/d' | sort | uniq -d)"
local target_domain_list_count_all=$(echo "$target_domain_list" | wc -l)
local a=0
for i in $target_domain_list; do
	End_target=$((${target_domain_list_count_all} - $a))
	a=$(($a + 1))
	same_fiter_rule=$(escape_special_chars "${i}")
	sed -i -E "/^${same_fiter_rule}\\$/d" "${file}"
	echo "※去除域名规则(${target_domain_list_count_all} → ${End_target}) ${i}"
done
}

#去除重复的域名规则
function clear_domain_white_list_shell(){
local file="${1}"
test ! -f "${file}" && return
cat "${file}" | sed '/^\!/d;/\#/d;/\$/d' | grep -E '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(:[0-9]{1,5})?(/[^ ]*)?' | sort -u | while read line
do
	transfer_content=`escape_special_chars ${line}`
	grep -E "^\|\|${transfer_content}\^" "${file}" && sed -i -E "/^${transfer_content}$/d" "${file}"
done
}

#去除与白名单冲突的域名
function clear_domain_white_Rules_shell(){
local file="${1}"
test ! -f "${file}" && return
cat "${file}" | grep -E 'domain=~' | sed '/#/d;s/\$.*//g' | while read line
do
	transfer_Rules=`escape_special_chars ${line}`
	sed -i -E "/^${transfer_Rules}$/d" "${file}"
done
}

#修复低级错误
function fixed_Rules_error_shell(){
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

function fixed_css_white_conflict(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "css_conflict" "${file}"
else
	fixed_css_white_conflict_shell "${file}"
fi
}

function fixed_css_selector_not_clean(){
local file="${1}"
test ! -f "${file}" && return
local python_file="`pwd`/Adblock_sort_other.py"
if command -v python3 >/dev/null 2>&1 && [ -f "${python_file}" ] ;then
	python3 "${python_file}" "css_selector_not_clean" "${file}"
fi
}

function wipe_same_selector_fiter(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "wipe_selector" "${file}"
else
	wipe_same_selector_fiter_shell "${file}"
fi
}

function clear_domain_white_list(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "clear_white" "${file}"
else
	clear_domain_white_list_shell "${file}"
fi
}

function clear_domain_white_Rules(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
	python3 "`pwd`/Adblock_sort_other.py" "clear_white_rules" "${file}"
else
	clear_domain_white_Rules_shell "${file}"
fi
}

function fixed_Rules_error(){
local file="${1}"
test ! -f "${file}" && return
if command -v python3 >/dev/null 2>&1 ;then
    python3 "`pwd`/Adblock_sort_other.py" "fixed_error" "${file}"
else
	fixed_Rules_error_shell "${file}"
fi
}

#去除badfilter对应规则
function wipe_badfilter(){
local file="${1}"
test ! -f "${file}" && return 0
grep -E '(\$|\,)badfilter' "${file}" | while read fitter
do
	select_after=$(echo ${fitter} | sed -E 's/\,badfilter$//g;s/\,badfilter\,/\,/g;s/\$badfilter//g')
	selector=$(escape_special_chars ${select_after})
	sed -i -E "/^${selector}$/d" "${file}"
done
}

# 转换成原生 has 规则
function add_has_fiter() {
local file="${1}"
local target_folder="${2}"
local target_website="${3}"
test ! -f "${file}" -o ! -d "${target_folder}" && return
local exclude=':-abp-contains|:-abp-properties|:contains|:has-text'
exclude="${exclude}|:matches-attr|:matches-css|:matches-css-after|:matches-css-before"
exclude="${exclude}|:matches-path|:matches-property|:min-text-length|:nth-ancestor"
exclude="${exclude}|:remove|:style|:upward|:watch-attr|:xpath"
exclude="${exclude}|[[:space:]]\{[[:space:]]remove:[[:space:]]true;[[:space:]]\}"
exclude="${exclude}|^#|^!|^\[|\*#"
local site_filter='^'
test -n "${target_website}" && site_filter="${target_website}"
local has_fiter="$(grep -E ':-abp-has|:has' "${file}" \
 | grep -E "${site_filter}" \
 | grep -Ev "${exclude}" \
 | sed -E 's/#(#|[@?]#)?/##/g;s/:-abp-has/:has/g' \
 | sort -u)"
write_notran_file "${has_fiter}" "${target_folder}/${file##*/}_has.txt"
}

#精简规则，剔除Via不支持的规则
#2026.09.19 grep 加入了正则移除 -e '^/(\^|\\|\[|\(\?)' 
#该规则和 Remove_regex_Rules_for_via 相似 是粗略过滤
#2026.09.20 sed 改为 sed -E 使用正则来缩短行数和方便维护，不要除去-E选项，不然无法过滤
function lite_Adblock_Rules(){
local file="${1}"
test ! -f "${file}" && return
local lite_content="$(grep -Ev \
 -e '#(@?[%$?]+)#' \
 -e '#@?#\+js\(' \
 -e '#@?#\^' \
 -e '\$@\$' \
 -e '(\$|,)~?(badfilter|empty|generichide|match-case|object|object-subrequest|removeparam)(,|$)' \
 -e '(\$|,)~?(csp|redirect-rule)(,|=|$)' \
 -e '(\$|,)~?(cname|genericblock|ghide|elemhide|ping|popunder)(,|$)' \
 -e '(\$|,)(redirect|removeparam|header|replace|urlskip|uritransform|ipaddress|method|csp|denyallow|permissions|to)=' \
 -e ':(matches-path|-abp-contains|-abp-properties|contains|has-text|matches-css|matches-css-before|matches-css-after|xpath|nth-ancestor|upward|remove|style|watch-attr|matches-attr|matches-property|min-text-length)' \
 -e ':others\(|:shadow\(' \
 -e '^/(\^|\\|\[|\(\?)' \
 -e '^\*$' \
 "${file}" | sed -E \
  -e '/^\!/d' \
  -e '/^[[:space:]]*$/d' \
  -e 's/(\$|,)from=/\1domain=/g' \
  -e 's/(\$|,)strict3p(,|$)/\1third-party\2/g' \
  -e 's/(\$|,)(~?)3p(,|$)/\1\2third-party\3/g' \
  -e 's/(\$|,)~1p(,|$)/\1third-party\2/g' \
  -e 's/(\$|,)1p(,|$)/\1~third-party\2/g' \
  -e 's/(\$|,)(~?)xhr(,|$)/\1\2xmlhttprequest\3/g' \
  -e 's/(\$|,)(~?)css(,|$)/\1\2stylesheet\3/g' \
  -e 's/(\$|,)(~?)i?frame(,|$)/\1\2subdocument\3/g' \
  -e 's/\$~?(important|popup|document|all|doc)(,|$)/$\2/g' \
  -e 's/,~?(important|popup|document|all|doc)(,|$)/\2/g' \
  -e 's/\$,/$/g' \
  -e 's/,,/,/g' \
  -e 's/\$$//' | sort -u )"
write_notran_file "${lite_content}" "${file}"
}

#在Via支持正则表达式前先移除正则表达式，减少报错和资源占用。
function Remove_regex_Rules_for_via(){
local file="${1}"
test ! -f "${file}" && return
sed -i -E '/\\\//d;/\\\./d;/\\\?/d' "${file}"
}

function count_filter_files() {
local _cf_file _cf_n _cf_div _cf_s _cf_q _cf_r
for _cf_file in "$@"
do
	case "$_cf_file" in [0-9]*) _cf_n="$_cf_file" ;; *) [ -f "$_cf_file" ] && [ -r "$_cf_file" ] || continue; _cf_n=$(wc -l < "$_cf_file" 2>/dev/null) ;; esac
	case "$_cf_n" in ''|*[!0-9]*|0) continue ;; esac
	[ "$_cf_n" -lt "1000" ] && { echo "$_cf_n"; continue; }
	if [ "$_cf_n" -lt "10000" ]; then
		_cf_div="1000"; _cf_s="k"
	else
		_cf_div="10000"; _cf_s="w"
	fi
	_cf_q=$((_cf_n / _cf_div)); _cf_r=$((_cf_n % _cf_div))
	[ "$_cf_r" = "0" ] && echo "${_cf_q}${_cf_s}" || echo "${_cf_q}.$((_cf_r * 10 / _cf_div))${_cf_s}"
done
}

#更新README信息
function update_README_info(){
local file="`pwd`/README.md"
test -f "${file}" && rm -rf "${file}"
cat << key > "${file}"
# Ublock filter for Via
> (`date +'%F %T'`)
> 将Ublock规则转为Via可用的规则，每12小时更新一次。

### 规则数: **$(count_filter_files "$(pwd)/Ublock_filter_for_via.txt")**

### 订阅规则
- Raw原链接
\`\`\`
https://raw.githubusercontent.com/lingeringsound/Ublock_filter_for_via/refs/heads/main/Ublock_filter_for_via.txt
\`\`\`
- CDN镜像链接
\`\`\`
https://cdn.jsdelivr.net/gh/lingeringsound/Ublock_filter_for_via@main/Ublock_filter_for_via.txt
\`\`\`

### 上游规则
#### 感谢各位大佬❤ (ɔˆз(ˆ⌣ˆc)
- [ublockorigin.github.io](https://ublockorigin.github.io/uAssets)
key
}

