#!/usr/bin/env bash

SOURCE_DIR=$(realpath $(dirname "${BASH_SOURCE}"))

. "$SOURCE_DIR/lib/argsparse.sh"

# ---------------------------------------------------------------------------- #
#                                   Wrappers                                   #
# ---------------------------------------------------------------------------- #

stdin::is_terminal() {
	[[ -t 0 ]]
}
export -f stdin::is_terminal

stdout::is_terminal() {
	[[ -t 1 ]]
}
export -f stdout::is_terminal

stdin::is_pipe() {
	[[ -t 0 ]]
}
export -f stdin::is_pipe

stdout::is_pipe() {
	[[ -t 1 ]]
}
export -f stdout::is_pipe

cmd::exists() {
	command -v "$@"
}
export -f cmd::exists

# ---------------------------------------------------------------------------- #
#                                      IO                                      #
# ---------------------------------------------------------------------------- #
print::error() {
	echo "$@" 1>&2
}

# ---------------------------------------------------------------------------- #
#                               String Processing                              #
# ---------------------------------------------------------------------------- #

string::replace() { (
	argsparse_pgm="${FUNCNAME[0]}"
	argsparse_describe_parameters to_replace replace_with string?
	argsparse_use_option =ignore_case "Ignore case."
	argsparse_parse_options "$@"

	if argsparse_is_option_set "ignore_case"; then
		ignore_case_opt="i"
	else
		ignore_case_opt=""
	fi

	if stdin::is_terminal; then
		echo "${program_params[2]}" | sed -r "s/${program_params[0]}/${program_params[1]}/g$ignore_case_opt"
	else
		cat | sed -r "s/${program_params[0]}/${program_params[1]}/g$ignore_case_op"
	fi
); }
export -f string::replace

string::split() { (
	argsparse_pgm="${FUNCNAME[0]}"
	argsparse_describe_parameters string delimiter
	argsparse_parse_options "$@"

	IFS="${program_params[1]}" read -ra arr <<<"${program_params[0]}"
	for i in "${arr[@]}"; do
		echo "$i" | sed -r s'/^\s*(.+)\s*$/\1/'
	done
); }
export -f string::split

string::trim() { (
	argsparse_pgm="${FUNCNAME[0]}"
	argsparse_parse_options "$@"

	: "${1#"${1%%[![:space:]]*}"}"
	: "${_%"${_##*[![:space:]]}"}"
	printf '%s\n' "$_"
); }
export -f string::trim

string::length() { (
	local input=""

	if stdin::is_terminal; then
		input="${@}"
	else
		input="$(cat)"
	fi

	if [[ -z "${input}" ]]; then
		print::error "Input cannot be empty."
		return 1
	fi

	echo "${#input}"
); }
export -f string::length

# ---------------------------------------------------------------------------- #
#                                Bash Utilities                                #
# ---------------------------------------------------------------------------- #

bash::newsh() { (
	argsparse_pgm="${FUNCNAME[0]}"
	argsparse_describe_parameters filename
	argsparse_parse_options "$@"

	file_basename=$(string::replace -i '.sh$' '' "${program_params[0]}")
	file_basename="$file_basename.sh"

	echo '#!/usr/bin/env bash' >"$file_basename"
	echo '' >>"$file_basename"
	echo '# -e: exit on unhandled error; -u: exit on unused var; -o: set return code to failed (-x: print cmd executed)' >>"$file_basename"
	echo 'set -euo pipefail ' >>"$file_basename"
	echo '' >>"$file_basename"
	echo 'SOURCE_DIR="${BASH_SOURCE%/*}"' >>"$file_basename"
); }
export -f bash::newsh

# ---------------------------------------------------------------------------- #
#                                    Custom                                    #
# ---------------------------------------------------------------------------- #
fuzzy::csv() { (
	argsparse_pgm="${FUNCNAME[0]}"
	argsparse_allow_no_argument
	argsparse_describe_parameters filename?
	argsparse_use_option =fzf: "FZF command to use." default:'fzf --header-lines=1'
	argsparse_use_option =padding: "Internal padding to use." default:5
	argsparse_parse_options "$@"

	if ! cmd::exists "xsv" >/dev/null; then
		echo "Install xsv using \`cargo install xsv\`."
		exit 1
	fi

	if stdin::is_terminal; then
		cmd="cat ${program_params[0]}"
	else
		cmd="cat"
	fi

	fzf_cmd=${program_options[fzf]}
	padding=${program_options[padding]}
	output=$($cmd | sed -r 's/\|/#/g' | xsv table -p "$padding" | sed -r "s/\s{$padding,$padding}(\s*)/\1 | /g" | $fzf_cmd)
	string::split "$output" "|"
); }
export -f fuzzy::csv
