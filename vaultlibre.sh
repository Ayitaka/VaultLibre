#!/bin/bash
#
# Install and Update VaultLibre from Docker Hub images or build from Github src
#
# ./vaultlibre.sh
# ./vaultlibre.sh install        [auto] [regencerts] [recreate]              - Install using images from Docker Hub
# ./vaultlibre.sh install build  [auto] [regencerts] [recreate]              - Install/build from Github src
#
# ./vaultlibre.sh updat          [auto] [regencerts] [recreate] [restart]    - Update using images from Docker Hub
# ./vaultlibre.sh update build   [auto] [regencerts] [recreate] [restart]    - Update from Github src
# ./vaultlibre.sh update rebuild [auto] [regencerts] [recreate] [restart]    - Update/force rebuild from Github src
#
# AUTO          Skip prompts, update this script, create certs only if they do not exist, and recreate docker-compose.override.yml
# REGENCERTS    Force regeneratioin of certificates
# RECREATE      Force recreation of docker-compose.override.yml
# RESTART       Force restart of Bitwarden if Bitwarden's update does not do a restart
# LOCALTIME     Force Bitwarden to write logs using localtime instead of UTC (use with RECREATE, or it has no effect)
#
# linter: https://www.shellcheck.net/

SCRIPT_VERSION="1.0.9"

GITHUB="Ayitaka"
REPO="VaultLibre"
BRANCH="main"
export DOCKERHUB="ayitaka"
export DOCKERHUBREPOAPI="vaultlibre-api"
export DOCKERHUBREPOIDENTITY="vaultlibre-identity"

initilize() {
	# Check that necessary commands are available
	check_cmd "curl" || { echo >&2 'Curl is required but not found.'; echo >&2 'Please check the documentation for your distribution to install it.'; exit 1; }
	check_cmd "docker" || { echo >&2 'Docker is required but not found.'; echo >&2 'Please check the documentation for your distribution to install it, or install it from https://docs.docker.com/engine/install/'; exit 1; }
	check_cmd "openssl" || { echo >&2 "OpenSSL is required but not found."; echo >&2 "Please check your distribution for how to install it."; exit 1; }
	check_cmd "jq" || { echo >&2 "jq is required but not found."; echo >&2 "Please check your distribution for how to install it."; exit 1; }

	# Turn CLI arguments into uppercase variables for install, restart, auto, regencerts, build, and/or recreate
	while [ -n "${1}" ]; do
		uppercasearg="${1^^}"
		[[ "${uppercasearg}" =~ ^INSTALL|RESTART|AUTO|REGENCERTS|RECREATE|LOCALTIME|BUILD|REBUILD$ ]] && declare "${uppercasearg}"=1
		shift
	done

	# Rebuild implies build, too
	[ "${REBUILD}" ] && BUILD=1

	BITWARDEN_BASE="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

	# Get Bitwarden base from user (or keep pwd)
	until [ -d "${BITWARDEN_BASE}" ] && [ -d "${BITWARDEN_BASE}/bwdata" ] && [ -f "${BITWARDEN_BASE}/bitwarden.sh" ]; do
		echo "Unable to find base directory containing bitwarden.sh and the bwdata directory at ${BITWARDEN_BASE}"
	    if [ "${AUTO}" ]; then
			exit 1;
		fi
		read -rp "Location of Bitwarden's base directory: " BITWARDEN_BASE
	done

	BW_VERSION=$(curl -sL https://raw.githubusercontent.com/bitwarden/self-host/master/version.json | jq -r ".versions.coreVersion")
	export BW_VERSION
    VL_VERSION=$(curl -sL https://raw.githubusercontent.com/Ayitaka/VaultLibre/master/versions.json | jq -r ".versions.Bitwarden.coreVersion")
	export VL_VERSION

	# Run main function
	main
}

main() {
	update_self

	compatibility_updates

	say "Installing VaultLibre for Bitwarden version $BW_VERSION"

	if [ "${BUILD}" ]; then
		build_vaultlibre
	fi

	get_generate_license_script


	# shellcheck disable=SC2153 # REGENCERTS is a command-line option turned into a "boolean" variable in initilize()
	if [ "${INSTALL}" ] || [ "${REGENCERTS}" ]; then
		regenerate_certs
	fi

	if [ "${INSTALL}" ] || [ "${RECREATE}" ] || [ "${AUTO}" ]; then
		recreate_override
	fi

	update_bitwarden
}

update_self() {
	# Check for updates to this script
	LATEST_SCRIPT_VERSION="$(curl --silent https://raw.githubusercontent.com/${GITHUB}/${REPO}/${BRANCH}/vaultlibre.sh | grep -e '^SCRIPT_VERSION="' | sed 's/^[^"]*"//; s/".*//' )"

	if [ -n "${LATEST_SCRIPT_VERSION}" ] && [ ! "${SCRIPT_VERSION}" == "${LATEST_SCRIPT_VERSION}" ]; then
		UPDATE_SCRIPT='n'

		if [ ! "${AUTO}" ]; then
			read -rp 'A new version of this script is available, would you like to update vaultlibre.sh now? [y/N]: ' tmpupdate
			UPDATE_SCRIPT=${tmpupdate:-$UPDATE_SCRIPT}
		fi

		if [ "${AUTO}" ] || [[ $UPDATE_SCRIPT =~ ^[Yy]$ ]]; then
			# shellcheck disable=SC2086 # Quoting makes ${ARG} incorrectly interpretted in certain situations
			curl --silent --retry 3 "https://raw.githubusercontent.com/${GITHUB}/${REPO}/${BRANCH}/vaultlibre.sh" -o "./vaultlibre.sh.tmp" && chmod 0755 ./vaultlibre.sh.tmp && mv ./vaultlibre.sh.tmp ./vaultlibre.sh && ./vaultlibre.sh ${ARGS}
		else
			echo "Ok. Skipping update and exiting."
		fi

		exit 0
	fi
}

compatibility_updates() {

        # After renaming project to VaultLibre, keys will exist in old ${BITWARDEN_BASE}/bwdata/bitbetter and need to be moved to ${BITWARDEN_BASE}/bwdata/vaultlibre
        [ -d "${BITWARDEN_BASE}/bwdata/vaultlibre" ] || mkdir -p "${BITWARDEN_BASE}/bwdata/vaultlibre"

        if [ -d "${BITWARDEN_BASE}/bwdata/bitbetter" ] && [ -n "$(ls -A "${BITWARDEN_BASE}/bwdata/bitbetter")" ]; then
                MOVE_CERTS='n'

                if [ ! "${AUTO}" ]; then
                        read -rp 'Certificates already exist from BitBetter. Would you like to use them? [y/N]: ' tmpmove
                        MOVE_CERTS=${tmpmove:-$MOVE_CERTS}
                else
                        MOVE_CERTS='y'
                fi

                if [[ $MOVE_CERTS =~ ^[Yy]$ ]]; then
                        mv "${BITWARDEN_BASE}/bwdata/bitbetter/"* "${BITWARDEN_BASE}/bwdata/vaultlibre/"
                        rm -rf "${BITWARDEN_BASE}/bwdata/bitbetter"
                fi
        fi

        if [ -f 'bitbetter.custom.override.yml' ] && [ ! -f 'vl.custom.override.yml' ]; then
                mv 'bitbetter.custom.override.yml' 'vl.custom.override.yml'
				sed -i 's/bitbetter/vaultlibre/g' vl.custom.override.yml
        fi

}

get_generate_license_script() {
	# Fetch generate_license script
	rm -f "${BITWARDEN_BASE}/vl_generate_license.sh"

	if [ "${BUILD}" ]; then
#		curl --silent --retry 3 "https://raw.githubusercontent.com/${GITHUB}/${REPO}/${BRANCH}/vl_generate_license_local.sh" -o "${BITWARDEN_BASE}/vl_generate_license.sh" && chmod 0755 "${BITWARDEN_BASE}/vl_generate_license.sh"
		cp -f "${BITWARDEN_BASE}/${REPO}/.build/vl_generate_license_local.sh" "${BITWARDEN_BASE}/vl_generate_license.sh"
	else
		curl --silent --retry 3 "https://raw.githubusercontent.com/${GITHUB}/${REPO}/${BRANCH}/vl_generate_license.sh" -o "${BITWARDEN_BASE}/vl_generate_license.sh" && chmod 0755 "${BITWARDEN_BASE}/vl_generate_license.sh"
	fi
}

regenerate_certs() {
	VAULTLIBRE_CERTS="${BITWARDEN_BASE}/bwdata/vaultlibre"

	[ -d "${BITWARDEN_BASE}/bwdata/vaultlibre" ] || mkdir -p "${BITWARDEN_BASE}/bwdata/vaultlibre"

	if [ "${BUILD}" ]; then
		[ -d "${BITWARDEN_BASE}/${REPO}/.keys" ] || mkdir -p "${BITWARDEN_BASE}/${REPO}/.keys"

		# If certs exist in VaultLibre/.keys, back them up and delete them
		if [ -e "${BITWARDEN_BASE}/${REPO}/.keys/cert.pem" ] || [ -e "${BITWARDEN_BASE}/${REPO}/.keys/key.pem" ] || [ -e "${BITWARDEN_BASE}/${REPO}/.keys/cert.cert" ] || [ -e "${BITWARDEN_BASE}/${REPO}/.keys/cert.pfx" ]; then
			mkdir -p "${VAULTLIBRE_CERTS}/backups"
			tar cvfz "${VAULTLIBRE_CERTS}/backups/certs.$(date '+%F-%H%M%S').tgz" --directory="${BITWARDEN_BASE}/${REPO}" .keys/cert.cert .keys/cert.pem .keys/cert.pfx .keys/key.pem >/dev/null
			rm -f "${BITWARDEN_BASE}/${REPO}/.keys/cert.cert" "${BITWARDEN_BASE}/${REPO}/.keys/cert.pem" "${BITWARDEN_BASE}/${REPO}/.keys/cert.pfx" "${BITWARDEN_BASE}/${REPO}/.keys/key.pem"
		fi

		# Soft link certs from VaultLibre/.keys/ to bwdata/vaultlibre/ so they are all in one place
		[ -L "${BITWARDEN_BASE}/${REPO}/.keys/cert.cert" ] || ln -s "${BITWARDEN_BASE}/bwdata/vaultlibre/cert.cert" "${BITWARDEN_BASE}/${REPO}/.keys/cert.cert"
		[ -L "${BITWARDEN_BASE}/${REPO}/.keys/cert.pem" ] || ln -s "${BITWARDEN_BASE}/bwdata/vaultlibre/cert.pem" "${BITWARDEN_BASE}/${REPO}/.keys/cert.pem"
		[ -L "${BITWARDEN_BASE}/${REPO}/.keys/cert.pfx" ] || ln -s "${BITWARDEN_BASE}/bwdata/vaultlibre/cert.pfx" "${BITWARDEN_BASE}/${REPO}/.keys/cert.pfx"
		[ -L "${BITWARDEN_BASE}/${REPO}/.keys/key.pem" ] || ln -s "${BITWARDEN_BASE}/bwdata/vaultlibre/key.pem" "${BITWARDEN_BASE}/${REPO}/.keys/key.pem"
	fi

	generate_certs() {
		# Generate cert
		say "Generating custom certificates"

		if [ -e "${VAULTLIBRE_CERTS}/cert.pem" ] || [ -e "${VAULTLIBRE_CERTS}/key.pem" ] || [ -e "${VAULTLIBRE_CERTS}/cert.cert" ] || [ -e "${VAULTLIBRE_CERTS}/cert.pfx" ]; then
			# Make a backup of current certs
			mkdir -p "${VAULTLIBRE_CERTS}/backups"
			tar cvfz "${VAULTLIBRE_CERTS}/backups/certs.$(date '+%F-%H%M%S').tgz" --directory="${VAULTLIBRE_CERTS}/.." vaultlibre/cert.cert vaultlibre/cert.pem vaultlibre/cert.pfx vaultlibre/key.pem >/dev/null
			rm -f "${VAULTLIBRE_CERTS}/cert.cert" "${VAULTLIBRE_CERTS}/cert.pem" "${VAULTLIBRE_CERTS}/cert.pfx" "${VAULTLIBRE_CERTS}/key.pem"
		fi

		# Generate new keys
		openssl	req -x509 -newkey rsa:4096 -keyout "${VAULTLIBRE_CERTS}/key.pem" -out "${VAULTLIBRE_CERTS}/cert.cert" -days 36500 -subj '/CN=www.mydom.com/O=My Company Name LTD./C=US'  -outform DER -passout pass:test
		openssl x509 -inform DER -in "${VAULTLIBRE_CERTS}/cert.cert" -out "${VAULTLIBRE_CERTS}/cert.pem"
		openssl pkcs12 -export -out "${VAULTLIBRE_CERTS}/cert.pfx" -inkey "${VAULTLIBRE_CERTS}/key.pem" -in "${VAULTLIBRE_CERTS}/cert.pem" -passin pass:test -passout pass:test

		# shellcheck disable=SC2086 # Globbing necessary
		chmod 644 ${VAULTLIBRE_CERTS}/*.cert ${VAULTLIBRE_CERTS}/*.pem ${VAULTLIBRE_CERTS}/*.pfx
	}

	if [ "${REGENCERTS}" ] || [ ! -d "${VAULTLIBRE_CERTS}" ] || [ ! -e "${VAULTLIBRE_CERTS}/cert.cert" ]; then
		generate_certs
	else
		if [ ! "${AUTO}" ]; then
			REGEN_CERT='n'
			read -rp 'Certificates already exist. Would you like to regenerate them? (Warning, this will cause any existing licenses to no longer work!!!) [y/N]: ' tmpregen
			REGEN_CERT=${tmpregen:-$REGEN_CERT}

			if [[ $REGEN_CERT =~ ^[Yy]$ ]]; then
				generate_certs
			fi
		fi
	fi
}

build_vaultlibre() {
	check_cmd "git" || { echo >&2 'Git is required but not found.'; echo >&2 'Please check the documentation for your distribution to install it.'; exit 1; }

	cd "${BITWARDEN_BASE}" || exit 1

	# Use subshell, to cd and git pull latest src from Github, so no need to 'cd ..' back
	if [ -d "${BITWARDEN_BASE}/${REPO}" ]; then
		(
			cd "${BITWARDEN_BASE}/${REPO}" || exit 1
			git pull origin ${BRANCH} >/dev/null 2>&1;
		)
	else
		git clone https://github.com/${GITHUB}/${REPO}.git >/dev/null 2>&1;
	fi

	# Stop and remove any docker hub images, to prevent overlap between local images and docker hub images
	iids=$( docker images ${DOCKERHUB}/* --format="{{ .ID }}" )
	if [ -n "$iids" ]; then
		"${BITWARDEN_BASE}/bitwarden.sh" stop
		# shellcheck disable=SC2086 # Quoting makes string unacceptable for rmi
		docker rmi -f ${iids}
	fi

	docker images vaultlibre/api --format="{{ .Tag }}" | grep -F -- "${BW_VERSION}" > /dev/null
	retval=$?

	BUILD_BB="n"
	BUILD_BB_DESCR="[y/N]"
	if [ $retval -ne 0 ] || [ "${REBUILD}" ]; then
	    BUILD_BB="y"
	    BUILD_BB_DESCR="[Y/n]"
	fi

	if [ ! "${AUTO}" ]; then
		read -rp "Build/Rebuild VaultLibre from source? $BUILD_BB_DESCR: " tmpbuild
		BUILD_BB=${tmpbuild:-$BUILD_BB}
	fi

	if [ "${REBUILD}" ] || [[ $BUILD_BB =~ ^[Yy]$ ]]; then

	    [ -e ${REPO}/src/vaultlibre/Dockerfile.dockerhub ] || mv ${REPO}/src/vaultlibre/Dockerfile ${REPO}/src/vaultlibre/Dockerfile.dockerhub
	    mv ${REPO}/.build/Dockerfile.vaultlibre ${REPO}/src/vaultlibre/Dockerfile

	    [ -e ${REPO}/src/licenseGen/Dockerfile.dockerhub ] || mv ${REPO}/src/licenseGen/Dockerfile ${REPO}/src/licenseGen/Dockerfile.dockerhub
	    mv ${REPO}/.build/Dockerfile.licenseGen ${REPO}/src/licenseGen/Dockerfile

		cd ${REPO} && ./build.sh

		cd src/licenseGen && ./build.sh
	fi
}

recreate_override() {
	# bwdata/docker/docker-compose.override.yml
	RECREATE_OV="y"

	if [ ! "${AUTO}" ] && [ ! "${RECREATE}" ] && [ -e "${BITWARDEN_BASE}/bwdata/docker/docker-compose.override.yml" ]; then
		read -rp "Rebuild docker-compose override? [Y/n]: " tmprecreate
		RECREATE_OV=${tmprecreate:-$RECREATE_OV}
	fi

	if [ "${AUTO}" ] || [ "${RECREATE}" ] || [[ $RECREATE_OV =~ ^[Yy]$ ]]; then
		{
			if [ "${BUILD}" ]; then
		        echo "version: '3'"
				echo ""
		        echo "services:"
		        echo "  api:"
		        echo "    image: vaultlibre/api:$BW_VERSION"
        		echo ""
		        echo "  identity:"
		        echo "    image: vaultlibre/identity:$BW_VERSION"
			else
				if [ -f 'vl.custom.override.yml' ]; then
					# Read custom override and substitute exported variables used in override. i.e. ${DOCKERHUB}/${DOCKERHUBREPOAPI}:$BW_VERSION
					envsubst < vl.custom.override.yml
				else
					echo "version: '3'"
					echo ""
					echo "services:"
					echo "  api:"
					echo "    image: ${DOCKERHUB}/${DOCKERHUBREPOAPI}:$BW_VERSION"
					echo "    volumes:"
					echo "      - ../vaultlibre/cert.cert:/newLicensing.cer"
					echo ""
					echo "  identity:"
					echo "    image: ${DOCKERHUB}/${DOCKERHUBREPOIDENTITY}:$BW_VERSION"
					echo "    volumes:"
					echo "      - ../vaultlibre/cert.cert:/newLicensing.cer"
				fi
			fi

			if [ "${LOCALTIME}" ]; then
				echo ""
				echo "  nginx:"
				echo "    volumes:"
				echo "      - /etc/localtime:/etc/localtime:ro"
			fi
		} > "${BITWARDEN_BASE}/bwdata/docker/docker-compose.override.yml"
	    say "VaultLibre docker-compose override created!"
	fi
}

update_bitwarden() {
	#if [ "$( docker container inspect -f '{{.State.Status}}' bitwarden-api )" == "running" ]; then
	#	docker stop bitwarden-api && docker rm bitwarden-api
	#fi
	#docker pull ${DOCKERHUB}/${DOCKERHUBREPOAPI}:${BW_VERSION}

	#if [ "$( docker container inspect -f '{{.State.Status}}' bitwarden-identity )" == "running" ]; then
	#	docker stop bitwarden-identity && docker rm bitwarden-identity
	#fi
	#docker pull ${DOCKERHUB}/${DOCKERHUBREPOIDENTITY}:${BW_VERSION}

	# Update bitwarden.sh, update Bitwarden, and if no update of Bitwarden was needed, restart Bitwarden for VaultLibre changes to take affect
	cd "${BITWARDEN_BASE}" || exit

	./bitwarden.sh updateself

	if [ "${BUILD}" ]; then
		awk '1;/function downloadRunFile/{c=6}c&&!--c{print "sed -i '\''s/dccmd pull/dccmd pull --ignore-pull-failures || true/g'\'' $SCRIPTS_DIR/run.sh"}' "${BITWARDEN_BASE}/bitwarden.sh" > tmp_bw.sh && mv tmp_bw.sh "${BITWARDEN_BASE}/bitwarden.sh"

		chmod +x "${BITWARDEN_BASE}/bitwarden.sh"
		say "Patching bitwarden.sh completed..."
	else
		if [ "${BW_VERSION}" != "${VL_VERSION}" ]; then
			say "VaultLibre images not updated yet, skipping update for now"
			exit;
		fi

		# Stop and remove any local images if this isn't a build, to ensure no overlap between local and docker hub images
		bids=$( docker images vaultlibre/* --format="{{ .ID }}" )
		if [ -n "$bids" ]; then
			"${BITWARDEN_BASE}/bitwarden.sh" stop
			# shellcheck disable=SC2086 # Quoting makes string unacceptable for rmi
			docker rmi -f ${bids}
		fi
	fi

	# shellcheck disable=SC2143 # Update is long no matter what, using -q for grep makes no difference?
	if [ "$( ./bitwarden.sh update | grep 'Update not needed' )" ]; then
		# If Bitwarden did not restart during update, restart it if INSTALL or RESTART are specified
		if [ "${INSTALL}" ] || [ "${RESTART}" ]; then
			./bitwarden.sh restart
		fi
	fi

	# Remove old instances of the VaultLibre images after update
	bids=$( docker images vaultlibre/* | grep -E -v -- "CREATED|latest|${BW_VERSION}" | awk '{ print $3 }' )
	# shellcheck disable=SC2015,SC2086 # Quoting makes string unacceptable for rmi
	[ -n "${bids}" ] && docker rmi -f ${bids} || true

	iids=$( docker images ${DOCKERHUB}/* | grep -E -v -- "CREATED|latest|${BW_VERSION}" | awk '{ print $3 }' )
	# shellcheck disable=SC2015,SC2086 # Quoting makes string unacceptable for rmi
	[ -n "${iids}" ] && docker rmi -f ${iids} || true
	# Works too
	# ids=$( docker images vaultlibre/* --format="{{ .ID }} {{ .Tag }}" | grep -E -v -- "latest|${BW_VERSION}" | awk '{ print $1 }' )
}

show_help() {
	echo "### vaultlibre.sh v${SCRIPT_VERSION} ###"
	echo ''
	echo 'Install and Update VaultLibre from Docker Hub images or build from Github src'
	echo ''
	echo './vaultlibre.sh'
	echo './vaultlibre.sh install        [auto] [regencerts] [recreate]              - Install using images from Docker Hub'
	echo './vaultlibre.sh install build  [auto] [regencerts] [recreate]              - Install/build from Github src'
	echo ''
	echo './vaultlibre.sh update         [auto] [regencerts] [recreate] [restart]    - Update using images from Docker Hub'
	echo './vaultlibre.sh update build   [auto] [regencerts] [recreate] [restart]    - Update from Github src'
	echo './vaultlibre.sh update rebuild [auto] [regencerts] [recreate] [restart]    - Update/force rebuild from Github src'
	echo ''
	echo 'AUTO          Skip prompts, update this script, create certs only if they do not exist, and recreate docker-compose.override.yml'
	echo 'REGENCERTS    Force regeneratioin of certificates'
	echo 'RECREATE      Force recreation of docker-compose.override.yml'
	echo "RESTART       Force restart of Bitwarden if Bitwarden's update does not do a restart"
	echo 'LOCALTIME     Force Bitwarden to write logs using localtime instead of UTC'
	echo ''
}

check_cmd() {
    command -v "$1" > /dev/null 2>&1
}

say() {
	if [ ! "${AUTO}" ]; then
		echo "$@"
	fi
}

if [[ "${1,,}" =~ help|-h|--help ]]; then
	show_help
	exit 0
fi

# Save CLI arguments
#ARGS="${@}"
ARGS="$*"

# Run the initilize function to start things up
initilize "${@}"
