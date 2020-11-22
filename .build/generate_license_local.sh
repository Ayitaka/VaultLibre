#!/bin/bash

if [ -e "${PWD}/bwdata/env/global.override.env" ]; then
        SERVER_INSTALLATION_ID=$( grep 'globalSettings__installation__id=' $PWD/bwdata/env/global.override.env | awk -F"=" '{print $2}' )
else
        echo "Unable to get globalSettings__installation__id from ${PWD}/bwdata/env/global.override.env. Aborting."
        exit 1
fi

TYPE=''
NAME=''
EMAIL=''
GUID=''
BUISNESS_NAME=''

if [ "${1,,}" == "help" ] || [ "${1,,}" == "--help" ] || [ "${1,,}" == "-h" ]; then
        echo ""
        echo "For use with BitBetter:"
        echo "https://github.com/${GITHUB}/${REPO}"
        echo ""
        echo "https://github.com/jakeswenson/BitBetter"
        echo "https://github.com/h44z/BitBetter"
        echo ""
        echo "To enter interactive mode:"
        echo "     generate_license.sh"
        echo ""
        echo "To use command-line:"
        echo "     generate_license.sh user USERS_NAME EMAIL USERS_GUID"
        echo "     generate_license.sh org ORGS_NAME EMAIL BUSINESS_NAME"
        echo ""
        echo "Example: generate_license.sh user SomeUser someuser@example.com 12345678-1234-1234-1234-123456789012"
        echo 'Example: generate_license.sh org "My Organization Display Name" admin@mybusinesscompany.com "My Company Inc."'
        echo ""
        exit
fi

until [ "${TYPE}" == "user" ] || [ "${TYPE}" == "org" ]; do
        if [ "${1,,}" == "user" ] || [ "${1,,}" == "org" ]; then
                TYPE="${1,,}"
        else
                read -rp 'Type of key (user or org): ' TYPE
                TYPE="${TYPE,,}"
        fi
done

if [ "${TYPE}" == "user" ]; then
        NAMEMSG="Please enter the user's full name: "
        EMAILMSG="Please enter the user's email address: "
        GUIDMSG="Please enter the user's GUID: "
elif [ "${TYPE}" == "org" ]; then
        NAMEMSG="Please enter a display name for the Organization: "
        EMAILMSG="Please enter an email address for the Organization: "
        GUIDMSG="Please enter the installation ID for the server: "
        BUSINESSNAMEMSG="Please enter the name of the business: "
else
        echo "Something went wrong, this should never happen"
        exit
fi

until [ -n "${NAME}" ]; do
        if [ -n "${2}" ]; then
                NAME="${2}"
        else
                read -rp "${NAMEMSG}" NAME
        fi
done

emailregex='^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'

until [ -n "${EMAIL}" ] && [[ "${EMAIL}" =~ $emailregex ]]; do
        if [ -n "${3}" ] && [[ "${3}" =~ $emailregex ]]; then
                EMAIL="${3}"
        else
                read -rp "${EMAILMSG}" EMAIL
        fi
done

if [ "${TYPE}" == "org" ]; then
        GUID="${SERVER_INSTALLATION_ID,,}"
fi

guidregex='^[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}$'

until [ -n "${GUID}" ] && [[ "${GUID}" =~ $guidregex ]]; do
        if [ -n "${4}" ] && [[ "${4}" =~ $guidregex ]]; then
                GUID="${4,,}"
        else
                read -rp "${GUIDMSG}" GUID
                GUID="${GUID,,}"
        fi
done

if [ "${TYPE}" == "org" ]; then
        until [ -n "${BUSINESS_NAME}" ]; do
                if [ -n "${4}" ]; then
                        BUSINESS_NAME="${4}"
                else
                        read -rp "${BUSINESSNAMEMSG}" BUSINESS_NAME
                fi
        done
fi

/root/BitBetter/src/licenseGen/run.sh /root/BitBetter/.keys/cert.pfx "${TYPE}" "${NAME}" "${EMAIL}" "${GUID}" "${BUSINESS_NAME}"
