# -*-eselect-*-  vim: ft=eselect
# Distributed under the terms of the GNU GPL version 2 or later

# This uses a portage-only module.

if [[ ! $(grep ":funtoo/1.0/linux-gnu/" /etc/portage/make.profile/parent 2> /dev/null) ]]; then

	# Copyright 2005-2017 Gentoo Foundation

	inherit package-manager

	DESCRIPTION="Manage the make.profile symlink"
	MAINTAINER="eselect@gentoo.org"

	DEFAULT_REPO="gentoo"

	# get location of make.profile symlink
	get_symlink_location() {
		local root=${PORTAGE_CONFIGROOT-${EROOT}}
		local oldloc=${root%/}/etc/make.profile
		local newloc=${root%/}/etc/portage/make.profile

		MAKE_PROFILE=${newloc}
		if [[ -e ${oldloc} ]]; then
			if [[ -e ${newloc} ]]; then
				write_warning_msg "Both ${oldloc} and ${newloc} exist."
				write_warning_msg "Using ${MAKE_PROFILE}."
			else
				MAKE_PROFILE=${oldloc}
			fi
		fi
	}

	# get list of repositories
	get_repos() {
		# sort: DEFAULT_REPO first, then alphabetical order
		portageq get_repos "${EROOT:-/}" \
			| sed "s/[[:space:]]\+/\n/g;s/^${DEFAULT_REPO}\$/ &/gm" \
			| LC_ALL=C sort
		[[ "${PIPESTATUS[*]}" = "0 0 0" ]]
	}

	# get paths for a given list of repositories
	get_repo_path() {
		portageq get_repo_path "${EROOT:-/}" "$@"
	}

	# get a list of valid profiles
	# returns a line <repo>::<repo_path>::<profile>::<status> for every profile
	find_targets() {
		local arch desc repos repo_paths i p

		arch=$(arch)
		[[ -z ${arch} ]] && die -q "Cannot determine architecture"

		repos=( $(get_repos) ) || die -q "get_repos failed"
		repo_paths=( $(get_repo_path "${repos[@]}") ) \
			|| die -q "get_repo_path failed"
		[[ ${#repos[@]} -eq 0 || ${#repos[@]} -ne ${#repo_paths[@]} ]] \
			&& die -q "Cannot get list of repositories"

		for (( i = 0; i < ${#repos[@]}; i++ )); do
			desc=${repo_paths[i]}/profiles/profiles.desc
			[[ -r ${desc} ]] || continue
			# parse profiles.desc and find profiles suitable for arch
			for p in $(sed -n -e \
				"s|^${arch}[[:space:]]\+\([^[:space:]]\+\)[[:space:]]\+\([^[:space:]]\+\).*$|\1::\2|p" \
				"${desc}")
			do
				echo "${repos[i]}::${repo_paths[i]}::${p}"
			done
		done
	}

	# remove make.profile symlink
	remove_symlink() {
		rm "${MAKE_PROFILE}"
	}

	# set the make.profile symlink
	set_symlink() {
		local target=$1 force=$2 targets arch parch repo repopath status

		if is_number "${target}"; then
			targets=( $(find_targets) )
			[[ ${#targets[@]} -eq 0 ]] \
				&& die -q "Failed to get a list of valid profiles"
			[[ ${target} -ge 1 && ${target} -le ${#targets[@]} ]] \
				|| die -q "Number out of range: $1"
			target=${targets[target-1]}
			repo=${target%%::*}; target=${target#*::}
			repopath=${target%%::*}; target=${target#*::}
			status=${target#*::}; status=${status%%::*}
			target=${target%%::*}
			if [[ ${status} == exp && -z ${force} ]]; then
				write_error_msg "Profile ${target} is experimental"
				die -q "Refusing to select ${status} profile without --force option"
			fi
		elif [[ -n ${target} ]]; then
			# if the profile was explicitly specified (rather than a number)
			# double check and make sure it's valid
			arch=$(arch)
			[[ -z ${arch} && -z ${force} ]] \
				&& die -q "Cannot determine architecture"
			repo=${target%%:*}
			# assume default repo if not explicitly specified
			[[ ${repo} == "${target}" || -z ${repo} ]] && repo=${DEFAULT_REPO}
			target=${target#*:}
			repopath=$(get_repo_path "${repo}") || die -q "get_repo_path failed"
			# do a reverse lookup and find the arch associated with ${target}
			parch=$(sed -n -e \
				"s|^\([[:alnum:]_-]\+\)[[:space:]]\+${target}[[:space:]].*$|\1|p" \
				"${repopath}/profiles/profiles.desc")
			[[ ${arch} != "${parch}" && -z ${force} ]] \
				&& die -q "${target} is not a valid profile for ${arch}"
		fi

		[[ -z ${target} || -z ${repopath} ]] \
			&& die -q "Target \"$1\" doesn't appear to be valid!"
		[[ ! -d ${repopath}/profiles/${target} ]] \
			&& die -q "No profile directory for target \"${target}\""

		# we must call remove_symlink() here instead of calling it from
		# do_set(), since if the link is removed, we cannot reliably
		# determine ${arch} in find_targets()
		if [[ -L ${MAKE_PROFILE} ]]; then
			remove_symlink \
				|| die -q "Couldn't remove current ${MAKE_PROFILE} symlink"
		fi

		# set relative symlink
		ln -s "$(relative_name \
			"${repopath}" "${MAKE_PROFILE%/*}")/profiles/${target}" \
			"${MAKE_PROFILE}" \
			|| die -q "Couldn't set new ${MAKE_PROFILE} symlink"
		# check if the resulting symlink is sane
		[[ $(canonicalise "${MAKE_PROFILE}") != "$(canonicalise "${EROOT}")"/* ]] \
			&& [[ -z ${force} ]] \
			&& write_warning_msg "Strange path. Check ${MAKE_PROFILE} symlink"

		return 0
	}

	### show action ###

	describe_show() {
		echo "Show the current make.profile symlink"
	}

	do_show() {
		local link repos repo_paths dir i

		get_symlink_location
		write_list_start "Current ${MAKE_PROFILE} symlink:"
		if [[ -L ${MAKE_PROFILE} ]]; then
			link=$(canonicalise "${MAKE_PROFILE}")
			repos=( $(get_repos) ) || die -q "get_repos failed"
			repo_paths=( $(get_repo_path "${repos[@]}") ) \
				|| die -q "get_repo_path failed"
			[[ ${#repos[@]} -eq 0 || ${#repos[@]} -ne ${#repo_paths[@]} ]] \
				&& die -q "Cannot get list of repositories"

			# Unfortunately, it's not obvious where to split a given path
			# in repository directory and profile. So loop over all
			# repositories and compare the canonicalised paths.
			for (( i = 0; i < ${#repos[@]}; i++ )); do
				dir=$(canonicalise "${repo_paths[i]}/profiles")
				if [[ ${link} == "${dir}"/* ]]; then
					link=${link##"${dir}/"}
					[[ ${repos[i]} != "${DEFAULT_REPO}" ]] \
						&& link=${repos[i]}:${link}
					break
				fi
			done
			write_kv_list_entry "${link}" ""
		else
			write_kv_list_entry "(unset)" ""
		fi
	}

	### list action ###

	describe_list() {
		echo "List available profile symlink targets"
	}

	do_list() {
		local targets active i target repo repopath status disp

		targets=( $(find_targets) )
		[[ ${#targets[@]} -eq 0 ]] \
			&& die -q "Failed to get a list of valid profiles"

		get_symlink_location
		active=$(canonicalise "${MAKE_PROFILE}")

		for (( i = 0; i < ${#targets[@]}; i++ )); do
			target=${targets[i]}
			repo=${target%%::*}; target=${target#*::}
			repopath=${target%%::*}; target=${target#*::}
			status=${target#*::}; status=${status%%::*}
			target=${target%%::*}
			disp=${target}
			[[ ${repo} != "${DEFAULT_REPO}" ]] && disp=${repo}:${disp}
			if ! is_output_mode brief; then
				disp+=" (${status})"
				[[ $(canonicalise "${repopath}/profiles/${target}") \
					== "${active}" ]] && disp=$(highlight_marker "${disp}")
			fi
			targets[i]=${disp}
		done
		write_list_start "Available profile symlink targets:"
		write_numbered_list "${targets[@]}"
	}

	### set action ###

	describe_set() {
		echo "Set a new profile symlink target"
	}

	describe_set_parameters() {
		echo "<target>"
	}

	describe_set_options() {
		echo "target : Target name or number (from 'list' action)"
		echo "--force : Forcibly set the symlink"
	}

	do_set() {
		local force
		if [[ $1 == "--force" ]]; then
			force=1
			shift
		fi

		[[ -z $1 ]] && die -q "You didn't tell me what to set the symlink to"
		[[ $# -gt 1 ]] && die -q "Too many parameters"

		get_symlink_location
		if [[ -e ${MAKE_PROFILE} ]] && [[ ! -L ${MAKE_PROFILE} ]]; then
			die -q "${MAKE_PROFILE} exists but is not a symlink"
		else
			set_symlink "$1" ${force} || die -q "Couldn't set a new symlink"
		fi
	}

else

	# Copyright 2005-2012 Gentoo Foundation
	# Copyright 2012-2013 Ryan P. Harris
	# Copyright 2015 Michał Górny

	# This version of profile.eselect is written for use with Funtoo's
	# multi-profile approach

	inherit package-manager output

	DESCRIPTION="Manage portage profiles"
	MAINTAINER="rh1@funtoo.org"
	VERSION="funtoo-1.9"

	### INIT ###

	# Global variables
	[[ -z "${MAKE_PROFILE_DIR}" ]] && MAKE_PROFILE_DIR="/etc/portage/make.profile"
	[[ -z "${PARENT_FILE}" ]] && PARENT_FILE="${MAKE_PROFILE_DIR}/parent"
	[[ -z "${MAIN_REPO_DIRECTORY}" ]] && MAIN_REPO_DIRECTORY="$(portageq portdir)"
	[[ -z "${MAIN_PROFILE_DIRECTORY}" ]] && MAIN_PROFILE_DIRECTORY="${MAIN_REPO_DIRECTORY}/profiles"
	[[ -z "${PROFILE_DESC_FILENAME}" ]] && PROFILE_DESC_FILENAME="profiles.eselect.desc"
	[[ -z "${MAIN_PROFILE_DESC_FILE}" ]] && MAIN_PROFILE_DESC_FILE="${MAIN_PROFILE_DIRECTORY}/${PROFILE_DESC_FILENAME}"
	[[ -z "${PORTAGE_OVERLAY_DIRS}" ]] && PORTAGE_OVERLAY_DIRS=( $(portageq portdir_overlay) )


	# We try to use global array variables anywhere we need to specify profile types
	# While it makes some of the code more complicated, it makes future maintenance
	# a lot easier if type names are changed or added to.

	# IMPORTANT Keep array variables in same order that profiles should appear in $PARENT_FILE.
	VALID_PROFILE_TYPES=( "arch" "subarch" "build" "flavor" "mix-ins" "mono" )
	REQUIRED_SINGLE_PROFILE_TYPES=( "arch" "build" "flavor" )
	MULTI_PROFILE_TYPES=( "arch" "subarch" "build" "flavor" "mix-ins" )
	MULTIPLE_PROFILES_ALLOWED_TYPES=( "mix-ins" )
	AUTO_ENABLED_PROFILE_TYPES=( "mix-ins" )
	CHECK_FOR_AUTO_ENABLED_PROFILE_TYPES=( "build" "flavor" "mix-ins" )
	MONOLITHIC_PROFILE_TYPE="mono"
	MACHINE_ARCH_TYPE="arch"

	# Die if MAIN_PROFILE_DESC_FILE doesn't exist
	if [[ ! -e "${MAIN_PROFILE_DESC_FILE}" ]] ; then
		die -q "Can't find ${MAIN_PROFILE_DESC_FILE}"
	fi

	# Create path to parent if needed.
	if [[ ! -e $(dirname "${PARENT_FILE}") ]] ; then
		mkdir -p $(dirname "${PARENT_FILE}")
	fi

	# Create $PARENT_FILE if it doesn't exist.
	if [[ ! -e "${PARENT_FILE}" ]] ; then
		touch "${PARENT_FILE}" || die -q "Error creating ${PARENT_FILE}"
		chmod 644 "${PARENT_FILE}"
	fi

	# Set VALID_ARCHS
	MACHINE_ARCH="$(arch)"
	case "${MACHINE_ARCH}" in
		amd64)
			VALID_ARCHS=( "x86-64bit" "pure64" )
			;;
		arm)
			# TODO: Fix for different arm versions
			VALID_ARCHS=( "arm-32bit" )
			;;
		x86)
			VALID_ARCHS=( "x86-32bit" )
			;;
		*)
			VALID_ARCHS=( "None" )
			;;
	esac


	### HELPER FUNCTIONS ###


	# PRIVATE
	# Assigns a value and returns it based on profile type for use in determining where to add profile
	# $1 = profile_type
	assign_profile_value() {
		local pro_type="${1}"
		local pro_type_number
		local count_num=1
		for profile_type in ${VALID_PROFILE_TYPES[@]} ; do
			if [[ "${pro_type}" == "${profile_type}" ]] ; then
				pro_type_number=${count_num}
			fi
			count_num="$(( ${count_num}+1 ))"
		done
		if [[ -z "${pro_type}" ]] ; then
			pro_type_number="${count_num}"
		fi
		echo "${pro_type_number}"
		return 0
	}


	# PUBLIC
	# Checks passed in profile against NoMix profiles for currently set
	# profiles and returns a list of any conflicting profiles it finds.
	# $1 = Profile to check against
	check_for_nomix() {
		local pro_to_check="${1}"
		local repo_name="$(get_repo_name ${pro_to_check})"
		local profile_desc_file="$(get_profiles_desc_file ${repo_name})"
		local pro_to_check_type="$(get_profile_type ${pro_to_check})"
		local stripped_pro_name

		if [[ -z "${repo_name}" ]] ; then
			# NoMix is only supported for new style multi profiles specified in format <repo_name>:<path_to_profile> so just return.
			return 0
		else
			stripped_pro_name="${pro_to_check#${repo_name}:}"
		fi

		local profile_path
		for profile_type in ${MULTI_PROFILE_TYPES[@]} ; do
			if [[ "${profile_type}" == "${pro_to_check_type}" ]] ; then
				profile_path="${stripped_pro_name%/${profile_type}/*}"
			fi
		done
		if [[ -z "${profile_path}" ]] ; then
			return 0
		fi

		local nomix=( $(awk '( $2 == "'"${stripped_pro_name}"'" ) && ( NF > 3 ) { print $4 }' "${profile_desc_file}" | awk -F "," '{ for ( x = 1; x <= NF; x++ ) { print $x } }') )
		if [[ -n "${nomix}" ]] ; then
			for profile in ${nomix[@]} ; do
				for current_pro in $(get_currently_set_profiles) ; do
					current_repo_name="$(get_repo_name ${current_pro})"
					if [[ "${repo_name}" == "${current_repo_name}" ]] ; then
						local full_pro="${repo_name}:${profile_path}/${profile}"
						if [[ "${full_pro}" == "${current_pro}" ]] ; then
							echo "${full_pro}"
						fi
					fi
				done
			done
		fi
		return 0
	}


	# PUBLIC
	# Creates and returns temporary file using mktemp and sets permissions to 644
	create_temp_file() {
		local temp_file="$(mktemp)"
		if (( $? != 0 )) ; then
			die -q "Error: Unable to create temporary file using 'mktemp'"
		fi
		chmod 644 "${temp_file}"
		echo "${temp_file}"
		return 0
	}


	# PUBLIC
	# Converts a full path for a profile to repo_name:profile format
	# $1 = path to convert
	convert_full_path_to_profile() {
		local pro_path="${1}"
		for repo in ${MAIN_REPO_DIRECTORY} ${PORTAGE_OVERLAY_DIRS[@]} ; do
			local repo_match="$(expr match "${pro_path}" "\(${repo}/profiles/\)")"
			if [[ "${repo_match}" == "${repo}/profiles/" ]] ; then
				if [[ -e "${repo_match}repo_name" ]] ; then
					local repo_name="$(cat ${repo_match}repo_name)"
					echo "${repo_name}:${pro_path#${repo_match}}"
					return 0
				else
					# repo_name file is required for this version to work right
					return 1
				fi

			fi
		done
		# If here then there was an error converting the full path
		return 1
	}


	# PUBLIC
	# Converts number from profile list to name of profile
	# $1 = Number to convert
	convert_list_number() {
		local pro_number="${1}"
		local profiles=( $(get_profiles_list) )
		# Added in validation for numbers.  It wasn't notifiying a number
		# was invalid if it was too large
		# psychopatch - 11-19-2012
		local profile_length=${#profiles[@]}
		if [[ ${1} -gt $profile_length ]]; then
			die -q "${1} is not a valid selection"
		fi
		echo "${profiles[$((${pro_number} - 1))]}"
	}


	# PUBLIC
	# Converts repo_name:profile format to full profile path
	# Returns full path to profile
	# $1 = profile to convert
	convert_profile_to_full_path() {
		local pro_to_convert="${1}"
		for repo in ${MAIN_REPO_DIRECTORY} ${PORTAGE_OVERLAY_DIRS[@]} ; do
			if [[ -e "${repo}/profiles/repo_name" ]] ; then
				local repo_name="$(get_repo_name ${pro_to_convert})"
				if [[ "${repo_name}" == "$(cat ${repo}/profiles/repo_name)" ]] ; then
					echo "${repo}/profiles/${pro_to_convert#${repo_name}:}"
					return 0
				fi
			fi
		done
		# If here then there was an error converting the profile
		return 1
	}


	# PUBLIC
	# Returns list of profiles in $PARENT_FILE
	get_currently_set_profiles() {
		while read line ; do
			if [[ "${line:0:1}" != "#" ]] ; then
				echo "${line}"
			fi
		done < "${PARENT_FILE}"
	}


	# PUBLIC
	# Searches all PROFILE_DESC_FILENAME files and returns any profiles of passed in type
	# $1 = profile type to search for
	get_profiles() {
		local profile_type="${1}"
		for pro_desc_file in $(get_profiles_desc_files) ; do
			local repo_name="$(get_repo_name_from_file ${pro_desc_file})"
			local profiles=( $(awk '$1 == "'"${profile_type}"'" { print $2 }' "${pro_desc_file}") )
			for profile in ${profiles[@]} ; do
				echo "${repo_name}:${profile}"
			done
		done
		return 0
	}


	# PUBLIC
	# Returns PROFILE_DESC_FILENAME file from passed in repo
	# $1 = Name of repo to get file from
	get_profiles_desc_file() {
		local repo_to_check="${1}"
		for pro_desc_file in $(get_profiles_desc_files) ; do
			local repo_name="$(get_repo_name_from_file ${pro_desc_file})"
			if [[ "${repo_name}" == "${repo_to_check}" ]] ; then
				echo "${pro_desc_file}"
				return 0
			fi
		done
		# If here then we didn't find a file.
		return 1
	}


	# PUBLIC
	# Returns list of profiles.desc files from main repo and those
	# found by looking in PORTDIR_OVERLAY repos.
	get_profiles_desc_files() {
		if [[ ! $(grep "core-kit:funtoo/1.0/linux-gnu/" /etc/portage/make.profile/parent 2> /dev/null) ]] ; then
			# Echo main repo first
			echo "${MAIN_PROFILE_DESC_FILE}"
		fi

		for repo in ${PORTAGE_OVERLAY_DIRS[@]} ; do
			if [[ -e "${repo}/profiles/${PROFILE_DESC_FILENAME}" ]] ; then
				echo "${repo}/profiles/${PROFILE_DESC_FILENAME}"
			fi
		done
		return 0
	}


	# PUBLIC
	# Searches through the passed in profile's parent file for profiles of types
	# specified in AUTO_ENABLED_PROFILE_TYPES.
	# Returns all matching profiles found
	# $1 = profile to search through
	get_profiles_enabled_by_profile() {
		local profile_to_check="${1}"
		local parent_file="$(convert_profile_to_full_path ${profile_to_check})/parent"

		if [[ ! -e "${parent_file}" ]] ; then
			return 0
		fi


		while read line ; do
			if [[ "${line:0:1}" == "#" ]] ; then
				continue
			fi

			# If line starts with a "/" then it's an absolute path. Otherwise
			# if line contains a ':' then it's a new style profile. If neither
			# apply then we assume the path is relative to the directory containing
			# the parent file.
			if [[ "${line:0:1}" == "/" ]] ; then
				# Absolute paths would only make sense if this was a
				# local user created profile in which case we just skip
				continue
			else
				local profile
				if [[ "${line}" == *:* ]] ; then
					# If a profile starts with ':' it is relative to the 'profiles' directory
					# that it's in.
					if [[ "${line:0:1}" == ":" ]] ; then
						local current_dir="$(pwd)"
						cd $(dirname "${parent_file}")
						local profile_dir="$(pwd)"
						while [[ "${profile_dir}" != "/" ]] ; do
							if [[ "$(basename ${profile_dir})" == "profiles" ]] ; then
								break;
							else
								profile_dir="$(dirname ${profile_dir})"
							fi
						done
						cd "${current_dir}"

						# If we didn't find a profiles dir then just skip
						if [[ "${profile_dir}" == "/" ]] ; then
							continue;
						fi

						local full_profile_path="${profile_dir}/${line:1}"
						profile="$(convert_full_path_to_profile ${full_profile_path})"
						if (( $? != 0 )) ; then
							continue
						fi

					else
						profile="${line}"
					fi
				else
					profile="$(dirname ${parent_file})/${line}"
					if [[ -e "${profile}" ]] ; then
						# Record pwd so we can return there after getting profile
						local current_dir="$(pwd)"
						cd "${profile}"
						profile="$(convert_full_path_to_profile $(pwd))"
						cd "${current_dir}"
						if (( $? != 0 )) ; then
							continue
						fi
					else
						continue
					fi
				fi

				local type_to_find
				for type_to_find in ${AUTO_ENABLED_PROFILE_TYPES[@]} ; do
					if [[ "$(get_profile_type ${profile})" == "${type_to_find}" ]] ; then
						echo "${profile}"
					fi
				done
			fi
		done < "${parent_file}"
		return 0
	}


	# PUBLIC
	# Returns full list of available profiles.
	get_profiles_list() {
		### MUST USE SAME ORDER AS write_numbered_list DOES SO convert_list_number WORKS ###
		for profile_type in ${VALID_PROFILE_TYPES[@]} ; do
			for pro_desc_file in $(get_profiles_desc_files) ; do
				local repo_name="$(get_repo_name_from_file ${pro_desc_file})"
				local profiles=( $(awk '$1 == "'"${profile_type}"'" { print $2 }' "${pro_desc_file}") )
				for profile in ${profiles[@]} ; do
					if [[ "${profile_type}" == "arch" ]] ; then
						local profile_matched="$(match_arch_profile ${profile})"
						if [[ "${profile_matched}" == "True" ]] ; then
							echo "${repo_name}:${profile}"
						else
							continue
						fi
					elif [[ ${profile_type} == subarch ]]; then
						local arch_parent=${profile%%/subarch/*}
						if [[ ${arch_parent} == ${profile} ]]; then
							die "${profile} is invalid subarch profile name (no subarch/)"
						fi
						if [[ $(is_profile_set "${repo_name}:${arch_parent}") == True ]]; then
							echo "${repo_name}:${profile}"
						else
							continue
						fi
					else
						echo "${repo_name}:${profile}"
					fi
				done
			done
		done
		return 0
	}


	# PUBLIC
	# Returns type of profile
	# $1 = Profile to check. Must be in format <repo_name>:<path_to_profile>
	get_profile_type() {
		local profile="${1}"
		local repo_name="$(get_repo_name ${profile})"
		for pro_desc_file in $(get_profiles_desc_files) ; do
			curr_name="$(get_repo_name_from_file ${pro_desc_file})"
			if [[ "${curr_name}" == "${repo_name}" ]] ; then
				# Check against $VALID_PROFILE_TYPES to insure correct values are retuned
				for pro_type in ${VALID_PROFILE_TYPES[@]} ; do
					# Strip repo_name
					local profile_type="$(awk '( $2 == "'"${profile#${repo_name}:}"'" ) && ( $1 == "'"$pro_type"'" ) { print $1 }' "${pro_desc_file}")"
					if [[ "${profile_type}" == "${pro_type}" ]] ; then
						echo "${profile_type}"
						return 0
					fi
				done
			fi
		done
	}


	# PUBLIC
	# Returns repo name found at beginning of profile.
	# $1 = Profile to check. Must be in format <repo_name>:<path_to_profile>
	get_repo_name() {
		local profile="${1}"
		local repo_name="$(expr match "${profile}" "\([^:]\+:\{1\}\)")"
		# Remove colon
		echo "${repo_name%:}"
	}


	# PUBLIC
	# Returns name of repo associated with the passed in PROFILE_DESC_FILENAME file
	# $1 = Full path to PROFILE_DESC_FILENAME file. Ex: /usr/portage/profiles/profiles.eselect.desc
	get_repo_name_from_file() {
		local repo_name_file="${1%${PROFILE_DESC_FILENAME}}repo_name"
		if [[ -e "${repo_name_file}" ]] ; then
			echo $(cat "${repo_name_file}")
		fi
	}


	# PUBLIC
	# Returns "True" if profile is set in $PARENT_FILE, "False" if not set.
	# $1 = Profile to look for
	is_profile_set() {
		local profile="${1}"
		for curr_pro in $(get_currently_set_profiles) ; do
			if [[ "${profile}" == "${curr_pro}" ]] ; then
				echo "True"
				return 0
			fi
		done
		# If we made it here, profile isn't set
		echo "False"
	}


	# PUBLIC
	# Checks if arch profile matches valid archs for machine. Returns True if matches, False if not.
	# Also returns True for all arches if VALID_ARCHS="None"
	# $1 = profile to check
	match_arch_profile() {
		local pro_to_check="${1}"
		local stripped_arch="${pro_to_check#*/arch/}"
		local pro_arch="${stripped_arch%%/*}"

		for valid_arch in ${VALID_ARCHS[@]} ; do
			if [[ "${valid_arch}" == "None" ]] ; then
				echo "True"
				return 0
			elif [[ "${pro_arch}" == "${valid_arch}" ]] ; then
				echo "True"
				return 0
			fi
		done
		# if here then no match
		echo "False"
		return 0
	}


	# PUBLIC
	# Returns all auto enabled profiles of type(s) defined by AUTO_ENABLED_PROFILE_TYPES
	# First parses the current profile for all profiles of types defined by CHECK_FOR_AUTO_ENABLED_PROFILE_TYPES and
	# then parses them for AUTO_ENABLED_PROFILE_TYPES.
	parse_auto_enabled_profiles() {

		# We must first build a list of profiles to check
		local profiles_to_check
		local profile_count=0 profile_offset=0
		for current_pro in $(get_currently_set_profiles) ; do
			for pro_type_to_check in ${CHECK_FOR_AUTO_ENABLED_PROFILE_TYPES[@]} ; do
				if [[ "$(get_profile_type ${current_pro})" == "${pro_type_to_check}" ]] ; then
					profiles_to_check=( ${profiles_to_check[@]} ${current_pro} )
				fi
			done
		done

		# Loop through the profiles we found so far and parse their parent files for any
		# more profiles that match what we're looking for. Keep looping until no more new profiles
		# are found.
		while (( ${profile_count} < ${#profiles_to_check[@]} )) ; do

			profile_offset=${profile_count}
			profile_count=${#profiles_to_check[@]}
			local new_profiles=()
			for pro_to_check in ${profiles_to_check[@]:${profile_offset}} ; do
				local current_profiles=( $(get_profiles_enabled_by_profile "${pro_to_check}") )
				# Check if profile is already added
				local current_profiles_count=${#current_profiles[@]}
				for (( i=0; i < ${current_profiles_count}; i++ )) ; do
					for new_pro in ${new_profiles[@]} ; do
						if [[ ${current_profiles[${i}]} == "${new_pro}" ]] ; then
							unset current_profiles[${i}]
						fi
					done
				done

				if (( ${#current_profiles[@]} > 0 )) ; then
					new_profiles=( ${new_profiles[@]} ${current_profiles[@]} )
				fi
			done

			# Check if profile is already added
			local new_profiles_count=${#new_profiles[@]}
			for (( i=0; i < ${new_profiles_count}; i++ )) ; do
				for pro_to_check in ${profiles_to_check[@]} ; do
					if [[ "${new_profiles[${i}]}" == "${pro_to_check}" ]] ; then
						unset new_profiles[${i}]
					fi
				done
			done

			if (( ${#new_profiles[@]} > 0 )) ; then
				profiles_to_check=( ${profiles_to_check[@]} ${new_profiles[@]} )
			fi

		done

		# Now loop through the profiles we found above and parse all of the auto-enables ones
		local auto_enabled_profiles
		for profile in ${profiles_to_check[@]} ; do
			local new_enabled_profiles=( $(get_profiles_enabled_by_profile ${profile}) )
			local profile_count=${#new_enabled_profiles[@]}
			for (( i = 0; i < ${profile_count}; i++ )) ; do
				# Check if already set
				local already_set="False"
				for auto_pro in ${auto_enabled_profiles[@]} ; do
					if [[ "${new_enabled_profiles[${i}]}" == "${auto_pro}" ]] ; then
						already_set="True"
					fi
				done
				if [[ "${already_set}" == "True" ]] ; then
					unset new_enabled_profiles[${i}]
				fi
			done
			auto_enabled_profiles=( ${auto_enabled_profiles[@]} ${new_enabled_profiles[@]} )
		done

		for profile in ${auto_enabled_profiles[@]} ; do
			echo "${profile}"
		done
		return 0
	}


	# PUBLIC
	# Processes passed in profile. Converts from number and validates profile strings.
	# Returns valid profile string
	# $1 = profile or number to process
	process_passed_in_profile() {
		local profile="${1}"
		if $(is_number "${profile}") ; then
			profile="$(convert_list_number ${profile})"
		else
			profile="$(validate_profile_string ${profile})"
		fi
		echo "${profile}"
	}


	# PUBLIC
	# Checks if parent file is valid.
	# Sets global variables with results
	validate_parent_file() {

		# Check if profiles are valid
		local invalid_profiles profile_count=0
		for profile in $(get_currently_set_profiles) ; do
			if [[ "$(validate_profile ${profile})" != "True" ]] ; then
				invalid_profiles["${profile_count}"]="${profile}"
				profile_count="$(( ${profile_count}+1 ))"
			fi
		done

		# Check if either no required profiles or too many set.
		local no_profile no_profile_count=0 extra_profiles extra_profiles_count=0
		for profile_type in ${REQUIRED_SINGLE_PROFILE_TYPES[@]} ; do
			local profile_count=0
			for profile in $(get_currently_set_profiles) ; do
				local curr_type="$(get_profile_type ${profile})"
				if [[ "${curr_type}" == "${profile_type}" ]] ; then
					profile_count="$(( ${profile_count}+1 ))"
				fi
			done
			if (( ${profile_count} == 0 )) ; then
				no_profile["${no_profile_count}"]="${profile_type}"
				no_profile_count="$(( ${no_profile_count} + 1 ))"
			elif (( ${profile_count} > 1 )) ; then
				extra_profiles["${extra_profiles_count}"]="${profile_type}"
				extra_profiles_count="$(( ${extra_profiles_count} + 1 ))"
			fi
		done

		# Check if mixing old style and new style profiles
		local old_style=0 new_style=0 mixed_profiles
		for profile in $(get_currently_set_profiles) ; do
			local current_type="$(get_profile_type ${profile})"

			if [[ "${current_type}" == "${MONOLITHIC_PROFILE_TYPE}" ]] ; then
				old_style="$(( ${old_style}+1 ))"
				continue
			else
				for profile_type in ${MULTI_PROFILE_TYPES[@]} ; do
					if [[ "${current_type}" == "${profile_type}" ]] ; then
						new_style="$(( ${new_style} + 1 ))"
						break
					fi
				done
			fi
		done

		# Set global variables with results. Set as strings, not array
		if (( ${#invalid_profiles} > 0 )) ; then
			INVALID_PROFILES="${invalid_profiles[@]}"
		fi
		# Not having profiles set is only error if not using an old style monolithic profile
		if (( ${#no_profile} > 0 && ${old_style} == 0 )) ; then
			MISSING_PROFILE_TYPES="${no_profile[@]}"
		fi
		if (( ${#extra_profiles} > 0 )) ; then
			EXTRA_PROFILE_TYPES="${extra_profiles[@]}"
		fi
		if (( ${old_style} > 0  && ${new_style} > 0 )) ; then
			MIXED_PROFILES="True"
		fi
		if (( ${old_style} > 0 && ${new_style} == 0 )) ; then
			USING_OLD_STYLE="True"
		fi

		return 0
	}


	# PRIVATE
	# Checks if profile exists. Returns "True" if it exists, "False" if it doesn't
	# NOTE: Only for profiles defined in PARENT_FILE.
	# $1 = Profile to check
	validate_profile() {
		local profile_valid profile="${1}"
		if [[ "${profile:0:1}" == "/" ]] ; then
			if [[ -d "${profile}" ]] ; then
				profile_valid="True"
			else
				profile_valid="False"
			fi
		elif [[ "${profile:0:1}" == "." ]] ; then
			if [[ -d "${MAKE_PROFILE_DIR}/${profile}" ]] ; then
				profile_valid="True"
			else
				profile_valid="False"
			fi
		elif [[ "${profile:0:1}" == ":" ]] ; then
			if [[ -d "${MAKE_PROFILE_DIR}/${profile:1}" ]] ; then
				profile_valid="True"
			else
				profile_valid="False"
			fi
		elif [[ -n "$(get_repo_name ${profile})" ]] ; then
			local repo_name="$(get_repo_name ${profile})"
			for pro_desc_file in $(get_profiles_desc_files) ; do
				curr_name="$(get_repo_name_from_file ${pro_desc_file})"
				if [[ "${curr_name}" == "${repo_name}" ]] ; then
					local full_profile="${pro_desc_file%${PROFILE_DESC_FILENAME}}${profile#${repo_name}:}"
					if [[ -d "${full_profile}" ]] ; then
						profile_valid="True"
						break
					else
						profile_valid="False"
						break
					fi
				fi
			done
			# If profile_valid isn't set then couldn't find profile, mark invalid
			if [[ -z "${profile_valid}" ]] ; then
				profile_valid="False"
			fi
		else
			# If here then not sure what this is. Doesn't appear to be valid profile.
			profile_valid="False"
		fi

		echo "${profile_valid}"
	}


	# PUBLIC
	# BUG FL-182
	# Validates a profile string entry against the list of profiles.
	# if the profile string doesn't exist, it errors out.
	# psychopatch 11-19-2012
	validate_profile_string() {
		local profile_string="${1}"
		local profiles=( $(get_profiles_list) )
		local repo_name=( $(get_repo_name_from_file ${MAIN_PROFILE_DESC_FILE}) )
		local profile_length=${#profiles[@]}
		# BUG FL-183
		# The eselect profile list command doesn't list the portage directory profile
		# prepending string "gentoo".  This leaves the user not knowing he needs to add it
		# simplist fix i could think of was to check for the : in the string, if it doesn't
		# exist, we add the master profile repo name to the beginning before we match
		# psychopatch - 11-19-2012
		if [[ "${profile_string}" != *:* ]]; then
			profile_string="${repo_name}:${profile_string}"
		fi
		for ((i=0; i<$profile_length; i++)) {
			if [[ "${profile_string}" == "${profiles[${i}]}" ]]; then
				echo "${profiles[${i}]}"
				return 0
			fi
		}
		die -q "${1} is not a valid selection"
		return 1
	}


	### ADD ACTION ###

	# PUBLIC
	# Adds a profile to $PARENT_FILE
	add_profile() {
		local pro_to_add="$(process_passed_in_profile ${1})"

		# Die if profile is already set
		if [[ "$(is_profile_set ${pro_to_add})" == "True" ]] ; then
			die -q "'${pro_to_add}' is already set in ${PARENT_FILE}"
		fi

		# Check for NoMix
		local nomix=( $(check_for_nomix "${pro_to_add}") )
		if [[ -n "${nomix}" ]] ; then
			if [[ -z "${FORCE_ADD}" ]] ; then
				die -q "Current profile contains the profile(s) '${nomix[@]}' which should not be used with '${pro_to_add}'. Use -f to override"
			fi
		fi

		# Assign value to profile type, used to determine where to add profile
		local pro_to_add_type="$(get_profile_type ${pro_to_add})"
		local pro_type_number="$(assign_profile_value ${pro_to_add_type})"

		# Loop through current profiles and add new one in right place
		local now_set="False"
		local temp_file="$(create_temp_file)"
		for current_pro in $(get_currently_set_profiles) ; do
			# Same as above, assign value to profile type
			local current_type="$(get_profile_type ${current_pro})"
			local current_type_number="$(assign_profile_value ${current_type})"
			# Check if trying to add more than one ${REQUIRED_SINGLE_PROFILE_TYPES}
			for profile_type in ${REQUIRED_SINGLE_PROFILE_TYPES[@]} ; do
				if [[ "${pro_to_add_type}" == "${profile_type}" && "${pro_to_add_type}" == "${current_type}" ]] ; then
					if [[ -z "${FORCE_ADD}" ]] ; then
						rm "${temp_file}"
						die -q "Your profile already contains a '${pro_to_add_type}' type profile. You should only have one set. Either use replace action or if you know what your doing you can override with '-f'"
					fi
				fi
			done
			if [[ "${now_set}" != "True" ]] ; then
				if (( ${current_type_number} <= ${pro_type_number} )) ; then
					echo "${current_pro}" >> "${temp_file}"
				else
					echo "${pro_to_add}" >> "${temp_file}"
					echo "${current_pro}" >> "${temp_file}"
					now_set="True"
				fi
			else
				echo "${current_pro}" >> "${temp_file}"
			fi
		done
		# If we didn't find spot to add above then just add to end of file.
		if [[ "${now_set}" != "True" ]] ; then
			echo "${pro_to_add}" >> "${temp_file}"
		fi

		# Move new parent file into place
		mv "${temp_file}" "${PARENT_FILE}" || die -q "Error trying to update parent file. Temp file = ${temp_file}, Parent file = ${PARENT_FILE}"

	}

	# PUBLIC
	# Description of add action
	describe_add() {
		echo "Adds profiles."
	}

	# PUBLIC
	# Called by eselect when passed add as action
	do_add() {
		# Parse cli args
		FORCE_ADD=""
		while getopts ":f" option ; do
			case ${option} in
				f)
					FORCE_ADD="--force"
					;;
				*)
					echo "Unrecognized option, use -f for force"
					;;
			esac
		done
		# Remove option args
		shift $(($OPTIND - 1))

		if [[ -z "${1}" ]] ; then
			die -q "You didn't tell me what profile to add"
		else
			for profile in ${@} ; do
				add_profile "${profile}"
			done
		fi
	}

	### CLEAN ACTION ###

	# PRIVATE
	# Cleans $PARENT_FILE of all invalid entries and corrects order of profiles
	# $1 = "-p" If set just prints what new $PARENT_FILE would contain
	clean_profiles() {
		# Need temporary parent file
		local temp_parent_file="$(create_temp_file)"

		# Get rid of any invalid profiles.
		for profile in $(get_currently_set_profiles) ; do
			if [[ "$(validate_profile ${profile})" == "True" ]] ; then
				echo "${profile}" >> "${temp_parent_file}"
			fi
		done

		# Copy original $PARENT_FILE location before changing variable
		local orig_parent_file="${PARENT_FILE}"
		PARENT_FILE="${temp_parent_file}"

		local current_profiles=( $(get_currently_set_profiles) )
		local current_profiles_count=${#current_profiles[@]}

		# Loop through valid profile types and current profiles to add in right place
		local temp_file=$(create_temp_file)
		for (( x=0; x<${#VALID_PROFILE_TYPES[@]}; x++ )) ; do
			local valid_type="${VALID_PROFILE_TYPES[${x}]}"
			for profile in ${current_profiles[@]} ; do
				curr_type="$(get_profile_type ${profile})"
				if [[ "${curr_type}" == "${valid_type}" ]] ; then
					echo "${profile}" >> "${temp_file}"
				fi
			done
		done

		# Remove all profiles we set above. Anything left goes at end of parent file
		for profile in $(cat "${temp_file}") ; do
			for (( x=0; x<${current_profiles_count}; x++ )) ; do
				if [[ "${profile}" == "${current_profiles[${x}]}" ]] ; then
					unset current_profiles[x]
				fi
			done
		done

		if (( ${#current_profiles[@]} > 0 )) ; then
			for profile in ${current_profiles[@]} ; do
				echo "${profile}" >> "${temp_file}"
			done
		fi

		# Clean up mess and either display results or update file
		PARENT_FILE="${orig_parent_file}"
		if [[ "${PRETEND_CLEAN}" == "True" ]] ; then
			echo
			write_list_start "Pretend flag set, Displaying diff of what would be changed:"
			diff -u ${PARENT_FILE} ${temp_file}
			echo
			rm "${temp_parent_file}"
			rm "${temp_file}"
		else
			rm "${temp_parent_file}"
			mv "${temp_file}" "${PARENT_FILE}"
		fi
	}

	# PUBLIC
	# Description of clean action
	describe_clean() {
		echo "Cleans up parent file. Removes invalid profiles. Fixes mis-ordered entries. Use '-p' to check what would be changed/removed."
	}

	# PUBLIC
	# Called by eselect when passed clean as action
	do_clean() {
		# Parse cli args
		PRETEND_CLEAN=""
		while getopts ":p" option ; do
			case ${option} in
				p)
					PRETEND_CLEAN="True"
					;;
				*)
					echo "Unrecognized option, use -p for pretend"
					;;
			esac
		done
		# Remove option args
		shift $(($OPTIND - 1))

		clean_profiles
	}

	### LIST ACTION ###

	# PRIVATE
	# Writes a list entry
	# $1 = List number, $2 = Name of profile, $3 = Type of profile
	write_numbered_profile_list_entry() {
		local list_num="${1}" profile="${2}" profile_type="${3}"

		# Must come before stripping repo name
		local profile_set=$(is_profile_set "${profile}")
		local auto_enabled="False"
		for auto_pro in ${CURRENT_AUTO_ENABLED_PROFILES[@]} ; do
			if [[ "${auto_pro}" == "${profile}" ]] ; then
				auto_enabled="True"
			fi
		done

		# Strip repo name if from main repo
		profile="${profile#gentoo:}"

		# Mark with "*" and highlight if in current profiles, add "auto" if auto-enabled
		if [[ "${profile_set}" == "True" && "${auto_enabled}" == "True" ]] ; then
			profile="${COLOUR_LIST_LEFT}${profile} * (auto)${COLOUR_NORMAL}"
		elif [[ "${profile_set}" == "True" ]] ; then
			profile="${COLOUR_LIST_LEFT}${profile} * ${COLOUR_NORMAL}"
		elif [[ "${auto_enabled}" == "True" ]] ; then
			profile="${COLOUR_LIST_LEFT}${profile} (auto) ${COLOUR_NORMAL}"
		fi

		# List number
		echo -n -e "  ${COLOUR_LIST_LEFT}"
		echo -n -e "[$(apply_text_highlights "${COLOUR_LIST_LEFT}" "${list_num}")]"
		echo -n -e "${COLOUR_NORMAL}"
		space $(( 4 - ${#list_num} ))

		# Profile name
		echo -n -e "${COLOUR_LIST_RIGHT}"
		echo -n -e "$(apply_text_highlights "${COLOUR_LIST_RIGHT}" "${profile}")"
		echo -e "${COLOUR_NORMAL}"
	}

	# PRIVATE  For use with write_numbered_profile_list(),
	# Prints list of <type> profiles.
	# $1 = profile type $2 = "True" if print this list otherwise "False".
	write_type_list() {
		local profile_type="${1}" print_list
		if [[ "${2}" == "True" ]] ; then
			print_list="True"
		else
			print_list="False"
		fi

		if [[ "${print_list}" == "True" ]] ; then
			write_list_start "Currently available ${profile_type} profiles:"
		fi

		for pro_desc_file in $(get_profiles_desc_files) ; do
			local repo_name="$(get_repo_name_from_file ${pro_desc_file})"
			local profiles=( $(awk '$1 == "'"${profile_type}"'" { print $2 }' "${pro_desc_file}") )
			for profile in ${profiles[@]} ; do
				if [[ "${profile_type}" == "arch" ]] ; then
					local profile_matched="$(match_arch_profile ${profile})"
					if [[ "${profile_matched}" == "True" ]] ; then
						if [[ "${print_list}" == "True" ]] ; then
							write_numbered_profile_list_entry "${LIST_ENTRY_NUMBER}" "${repo_name}:${profile}" "${profile_type}"
						fi
					else
						continue
					fi
				elif [[ ${profile_type} == subarch ]]; then
					local arch_parent=${profile%%/subarch/*}
					if [[ ${arch_parent} == ${profile} ]]; then
						die "${profile} is invalid subarch profile name (no subarch/)"
					fi
					if [[ $(is_profile_set "${repo_name}:${arch_parent}") == True ]]; then
						if [[ "${print_list}" == "True" ]] ; then
							write_numbered_profile_list_entry "${LIST_ENTRY_NUMBER}" "${repo_name}:${profile}" "${profile_type}"
						fi
					else
						continue
					fi
				else
					if [[ "${print_list}" == "True" ]] ; then
						write_numbered_profile_list_entry "${LIST_ENTRY_NUMBER}" "${repo_name}:${profile}" "${profile_type}"
					fi
				fi
				LIST_ENTRY_NUMBER=$(( ${LIST_ENTRY_NUMBER}+1 ))
			done
		done
	}

	# PRIVATE
	# Writes a numbered list of profiles
	# "$1 = Type of profiles to list or "all" for all valid types
	write_numbered_profile_list() {
		local list_type
		if [[ -z "${1}" ]] ; then
			list_type="all"
		else
			list_type="${1}"
		fi

		# Declare global vars here:
		# This is needed so that numbers on list will match entry order in get_profiles_list()
		LIST_ENTRY_NUMBER="1"
		# This is set here to avoid repeated calls to parse_auto_enabled_profiles.
		CURRENT_AUTO_ENABLED_PROFILES=( $(parse_auto_enabled_profiles) )

		for profile_type in ${VALID_PROFILE_TYPES[@]} ; do
			local print_list
			if [[ "${list_type}" == "all" || "${list_type}" == "${profile_type}" ]] ; then
				print_list="True"
			else
				print_list="False"
			fi

			# Only display profiles if present
			if [[ "${profile_type}" != "${list_type}" ]] ; then
				local profiles=( $(get_profiles "${profile_type}") )
				if [[ -n "${profiles[@]}" ]] ; then
					write_type_list "${profile_type}" "${print_list}"
				else
					continue
				fi
			else
				write_type_list "${profile_type}" "${print_list}"
			fi
		done
	}

	# PUBLIC
	# Description of list action
	describe_list() {
		echo "List available profile targets."
	}

	# PUBLIC
	# Called by eselect when passed list as action
	do_list() {
		write_numbered_profile_list "${1}"
	}

	### REMOVE ACTION ###

	# PUBLIC
	# Removes a profile
	# $1 = profile to remove
	remove_profile() {
		local pro_to_remove="$(process_passed_in_profile ${1})"

		local found_pro="False"
		local temp_file="$(create_temp_file)"
		for profile in $(get_currently_set_profiles); do
			if [[ "${profile}" == ${pro_to_remove} ]] ; then
				found_pro="True"
			else
				echo "${profile}" >> "${temp_file}"
			fi
		done

		if [[ "${found_pro}" == "False" ]] ; then
			rm "${temp_file}"
			auto_enabled="False"
			for profile in $(parse_auto_enabled_profiles) ; do
				if [[ "${profile}" == "${pro_to_remove}" ]] ; then
					auto_enabled="True"
				fi
			done

			if [[ "${auto_enabled}" == "True" ]] ; then
				die -q "${pro_to_remove} is automatically enabled by another profile and can't be removed"

			else
				die -q "'${pro_to_remove}' was not found in your current profiles"
			fi
		else
			mv "${temp_file}" "${PARENT_FILE}" || die -q "Error trying to update parent file. Temp file = ${temp_file}, Parent file = ${PARENT_FILE}"
		fi

	}

	# PUBLIC
	# Description of remove action
	describe_remove() {
		echo "Removes a profile."
	}

	# PUBLIC
	# Called by eselect when passed remove as action
	do_remove() {

		if [[ -z "${1}" ]] ; then
			die -q "You didn't tell me what profile to remove"
		else
			for profile in ${@} ; do
				remove_profile "${profile}"
			done
		fi
	}

	### REPLACE ACTION ###

	# PRIVATE
	# Replaces a profile in $PARENT_FILE
	# $1 = profile to remove $2 = profile to add_profile
	replace_profile() {
		local old_profile="$(process_passed_in_profile ${1})"
		local new_profile="$(process_passed_in_profile ${2})"

		# Copy original parent file to temp location before removing old profile, that way if something goes wrong we can restore it
		local orig_parent_file="$(create_temp_file)"
		cp "${PARENT_FILE}" "${orig_parent_file}"
		remove_profile "${old_profile}"

		# Check if profile already set
		if [[ "$(is_profile_set ${new_profile})" == "True" ]] ; then
			mv "${orig_parent_file}" "${PARENT_FILE}"
			die -q "'${new_profile}' is already set in ${PARENT_FILE}"
		fi

		# Check for NoMix
		local nomix=( $(check_for_nomix ${new_profile}) )
		if [[ -n "${nomix}" ]] ; then
			if [[ -z "${FORCE_REPLACE}" ]] ; then
				mv "${orig_parent_file}" "${PARENT_FILE}"
				die -q "Current profile contains the profile(s) '${nomix[@]}' which should not be used with '${new_profile}'. Use -f to override"
			fi
		fi

		# Get type number for new profile
		local new_profile_type="$(get_profile_type ${new_profile})"
		new_pro_type_number="$(assign_profile_value ${new_profile_type})"

		# Loop through current profiles and decide where to add new one.
		local now_set="False"
		local temp_file="$(create_temp_file)"
		for current_pro in $(get_currently_set_profiles) ; do
			# Assign value to profile type
			local current_type="$(get_profile_type ${current_pro})"
			local current_type_number="$(assign_profile_value ${current_type})"

			# Check if trying to add more than one ${REQUIRED_SINGLE_PROFILE_TYPES}
			for profile_type in ${REQUIRED_SINGLE_PROFILE_TYPES[@]} ; do
				if [[ "${new_profile_type}" == "${profile_type}" && "${new_profile_type}" == "${current_type}" ]] ; then
					if [[ -z "${FORCE_REPLACE}" ]] ; then
						rm "${temp_file}"
						mv "${orig_parent_file}" "${PARENT_FILE}"
						die -q "Your profile already contains a '${new_profile_type}' type profile. You should only have one set. Either use replace action or if you know what your doing you can override with '-f'"
					fi
				fi
			done
			if [[ "${now_set}" != "True" ]] ; then
				if (( ${current_type_number} <= ${new_pro_type_number} )) ; then
					echo "${current_pro}" >> "${temp_file}"
				else
					echo "${new_profile}" >> "${temp_file}"
					echo "${current_pro}" >> "${temp_file}"
					now_set="True"
				fi
			else
				echo "${current_pro}" >> "${temp_file}"
			fi
		done

		# If we didn't find spot to add new profile above then just add to end of file.
		if [[ "${now_set}" != "True" ]] ; then
			echo "${new_profile}" >> "${temp_file}"
		fi

		# Move new parent file into place
		mv "${temp_file}" "${PARENT_FILE}"
		if (( $? != 0 )) ; then
			mv "${orig_parent_file}" "${PARENT_FILE}"
			rm "${temp_file}"
			die -q "Error trying to update parent file. Temp file was= ${temp_file}, Parent file = ${PARENT_FILE}"
		else
			rm "${orig_parent_file}"
		fi
	}

	# PUBLIC
	# Description of replace action
	describe_replace() {
		echo "Replaces a profile. Use -f to force. Usage: eselect profile replace [-f] <old_pro> <new_pro>"
	}

	# PUBLIC
	# Called by eselect when passed replace as action
	do_replace() {
		# Parse cli args
		FORCE_REPLACE=""
		while getopts ":f" option ; do
			case ${option} in
				f)
					FORCE_REPLACE="True"
					;;
				*)
					echo "Unrecognized option, Use -f for force"
					;;
			esac
		done
		# Remove option args
		shift $(($OPTIND - 1))

		if (( $# < 2 )) ; then
			die -q "The replace action requires 2 arguments. Usage: eselect profile replace [-f] <old_pro> <new_pro>"
		else
			replace_profile "${1}" "${2}"
		fi
	}


	### SET-BUILD ACTION ###

	# PUBLIC
	# Description of set-build action
	describe_set-build() {
		echo "Changes the build profile"
	}

	# PUBLIC
	# Adding a set-build action to go along with set-flavor action.
	do_set-build() {
		local pro_to_add="$(process_passed_in_profile ${1})"

		local profile_type="$(get_profile_type ${pro_to_add})"
		if [[ "${profile_type}" == "build" ]]
		then

			local profiles=( $(get_currently_set_profiles) )
			for i in "${profiles[@]}"
			do

				if [[ "$(get_profile_type ${i})" == "build" ]]
				then
					do_remove "${i}"
					break
				fi
			done
			do_add "${1}"
		else
			die -q "Selection is not a build profile"
		fi
	}


	### SET-FLAVOR ACTION ###

	# PUBLIC
	# Description of set-flavor action.
	describe_set-flavor() {
		echo "Changes the flavor profile"
	}

	# PUBLIC
	# FL-184
	# Adding a set-flavor function to allow an easier workflow
	# to replace system flavors.
	do_set-flavor() {
		local pro_to_add="$(process_passed_in_profile ${1})"

		local profile_type="$(get_profile_type ${pro_to_add})"
		if [[ "${profile_type}" == "flavor" ]]
		then
			#this is where the work to swap out the flavors happen.
			#get current flavor
			local profiles=( $(get_currently_set_profiles) )
			for i in "${profiles[@]}"
			do

				if [[ "$(get_profile_type ${i})" == "flavor" ]]
				then
					do_remove "${i}"
					break
				fi
			done
			#enable flavor
			do_add "${1}"
		else
			die -q "Selection is not a flavor profile"
		fi
	}


	### SET-SUBARCH ACTION ###

	# PUBLIC
	# Description of set-subarch action
	describe_set-subarch() {
		echo "Changes the subarch profile"
	}

	# PUBLIC
	# Adding a set-subarch action to go along with set-flavor action.
	do_set-subarch() {
		local pro_to_add="$(process_passed_in_profile ${1})"

		local profile_type="$(get_profile_type ${pro_to_add})"
		if [[ "${profile_type}" == "subarch" ]]
		then

			local profiles=( $(get_currently_set_profiles) )
			for i in "${profiles[@]}"
			do

				if [[ "$(get_profile_type ${i})" == "subarch" ]]
				then
					do_remove "${i}"
					break
				fi
			done
			do_add "${1}"
		else
			die -q "Selection is not a subarch profile"
		fi
	}


	### SHOW ACTION ###

	# PRIVATE
	# Displays currently set profiles
	show_profiles() {

		# Validate parent file so global vars are set
		validate_parent_file

		# Determine spacing
		local spaceme=1
		local no_type="(no type)"
		for profile_type in ${VALID_PROFILE_TYPES[@]} ${no_type} ; do
			if (( ${#profile_type} > ${spaceme} )) ; then
				spaceme=${#profile_type}
			fi
		done
		spaceme=$(( ${spaceme} + 1 ))

		# Get profiles and write list
		local profiles=( $(get_currently_set_profiles) )
		echo
		write_list_start "Currently set profiles:"
		if [[ "${USING_OLD_STYLE}" != "True" && "${MIXED_PROFILES}" != "True" && -z "${EXTRA_PROFILE_TYPES}" ]] ; then
			# Print required types first
			for (( x = 0 ; x < ${#REQUIRED_SINGLE_PROFILE_TYPES[@]}; x++ )) ; do
				local matched_profile="False"
				local profile_count="${#profiles[@]}"
				for (( y = 0; y < ${profile_count}; y++ )) ; do
					if [[ "${REQUIRED_SINGLE_PROFILE_TYPES[${x}]}" == "$(get_profile_type ${profiles[${y}]})" ]] ; then
						echo -e "$(space $(( spaceme -  ${#REQUIRED_SINGLE_PROFILE_TYPES[${x}]} )))${REQUIRED_SINGLE_PROFILE_TYPES[${x}]}: ${profiles[${y}]}"
						matched_profile="True"
						unset profiles[${y}]
					fi
				done
				profiles=( ${profiles[@]} )
				if [[ ${matched_profile} == "False" ]] ; then
					echo -e "$(space $(( spaceme -  ${#REQUIRED_SINGLE_PROFILE_TYPES[${x}]} )))${REQUIRED_SINGLE_PROFILE_TYPES[${x}]}: ${COLOUR_WARN}(missing)${COLOUR_NORMAL}"
				fi
			done

			# Print rest of profiles
			for pro in ${profiles[@]} ; do
				local pro_type=$(get_profile_type ${pro})
				if [[ -n "${pro_type}" ]] ; then
					echo -e "$(space $(( spaceme -  ${#pro_type} )))${pro_type}: ${pro}"
				else
					echo -e "$(space $(( spaceme -  ${#no_type} )))${no_type}: ${pro}"
				fi
			done

			# Print list of auto-enabled profiles
			local auto_enabled_profiles=( $(parse_auto_enabled_profiles) )
			if (( ${#auto_enabled_profiles[@]} > 0 )) ; then
				echo
				write_list_start "Automatically enabled profiles:"

				for auto_pro in ${auto_enabled_profiles[@]} ; do
					local pro_type=$(get_profile_type ${auto_pro})
					if [[ -n "${pro_type}" ]] ; then
						echo -e "$(space $(( spaceme -  ${#pro_type} )))${pro_type}: ${auto_pro}"
					else
						echo -e "$(space $(( spaceme -  ${#no_type} )))${no_type}: ${auto_pro}"
					fi
				done
			fi
		else
			# Using either old style or mixed profile(s) or user force-added extra profiles of same type, just print list.
			for pro in ${profiles[@]} ; do
				local pro_type=$(get_profile_type ${pro})
				if [[ -n "${pro_type}" ]] ; then
					echo -e "$(space $(( spaceme -  ${#pro_type} )))${pro_type}: ${pro}"
				else
					echo -e "$(space $(( spaceme -  ${#no_type} )))${no_type}: ${pro}"
				fi
			done
		fi
		echo
	}

	# PUBLIC
	# Description of show action
	describe_show() {
		echo "Displays list of profiles that are currently set."
	}

	# PUBLIC
	# Called by eselect when passed show as action
	do_show() {
		show_profiles
	}

fi
