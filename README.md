<a href="https://github.com/ayitaka/VaultLibre/actions"><img alt="GitHub Actions Build" src="https://github.com/ayitaka/VaultLibre/actions/workflows/VaultLibre.yml/badge.svg"></a>
<a href="https://hub.docker.com/r/ayitaka/vaultlibre-api"><img alt="Docker Pulls" src="https://img.shields.io/docker/pulls/ayitaka/vaultlibre-api.svg"></a>
# VaultLibre

VaultLibre is a tool to modify Bitwarden's core dll to allow generating custom User and Organization licenses. 

**(Note: You must have an existing installation of Bitwarden for VaultLibre to modify.)**

VaultLibre is based on the project <a href="https://github.com/jakeswenson/BitBetter">BitBetter</a>, with a number of key differences:
* VaultLibre can be used with publically available docker images or built yourself from src to run locally
* VaultLibre updates the docker images whenever there is an update to Bitwarden and makes them available via DockerHub
* VaultLibre has a script to handle installing (or building) and updating, with options to handle almost any use-case
* You can use the script to easily generate User and Organization licenses

**Use VaultLibre at your own risk. Be sure to make a backup of the bwdata folder before installing VaultLibre or upgrading.**

Credit to:
* <a href="https://github.com/jakeswenson/BitBetter">jakeswenson</a> for the original BitBetter project
* <a href="https://github.com/h44z/BitBetter">h44z</a> for all their contributions to the original project
* <a href="https://github.com/alexyao2015/BitBetter">alexyao2015</a> for creating the starting point for adding docker images

# Table of Contents
1. [Getting Started](#getting-started)
    + [Dependencies](#dependencies)
    + [Installing VaultLibre](#installing-vaultlibre)
    + [Updating VaultLibre and Bitwarden](#updating-vaultlibre-and-bitwarden)
    + [Generating Signed Licenses](#generating-signed-licenses)
2. [Script Options](#script-options)
3. [Advanced](#advanced)
    + [Building VaultLibre](#building-vaultlibre)
    + [Updating Built VaultLibre and Bitwarden](#updating-built--vaultlibre-and-bitwarden)
    + [Manually Generating Certificate](#manually-generating-certificate)
    + [Manually Generating Signed Licenses](#manually-generating-signed-licenses)
    + [Using A Custom Docker Override](#using-a-custom-docker-override)
4. [FAQ](#faq-questions-you-might-have-)
5. [Footnotes](#footnotes)

# Getting Started
The following instructions are for unix-based systems (Linux, BSD, macOS). It is possible to use a Windows based system, assuming you are able to enable and install [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

## Dependencies
* docker
* docker-compose
* curl
* openssl
* jq
* Bitwarden Server

## Installing VaultLibre
The easiest way to install VaultLibre is to use the vaultlibre.sh script to utilize the public VaultLibre docker images. These docker images are compiled automatically anytime a new version of Bitwarden is released or when changes are made to VaultLibre.

#### Run the install script:

```bash
curl --retry 3 "https://raw.githubusercontent.com/Ayitaka/VaultLibre/main/vaultlibre.sh" -o "./vaultlibre.sh" && chmod 0700 ./vaultlibre.sh && ./vaultlibre.sh install
```

For available options, see [Script Options](#script-options)

## Updating VaultLibre and Bitwarden

#### Using the vaultlibre script, you can update both VaultLibre and Bitwarden:
```bash
./vaultlibre.sh update auto
```

#### Adding a crontab for updating
```bash
#### VaultLibre Mon-Sat @ 2:22am
22 2 * * 1-6 cd ${HOME} && ./vaultlibre.sh auto update recreate localtime >/dev/null 
#### VaultLibre Sun @ 2:22am force restart to allow updating LetsEncrypt if necessary
22 2 * * 0 cd ${HOME} && ./vaultlibre.sh auto update recreate localtime restart >/dev/null
```

## Generating Signed Licenses
Licenses are used for enabling certain features. There are licenses for Users and for Organizations. You can use the vaultlibre.sh script to generate licenses, or the vl_generate_license.sh script. Once you have generated a license, copy it and save it in a txt file. Then use the saved file to upload the license in the settings when you are logged into the applicable account.

#### For a user:
```bash
./vaultlibre.sh generate_license user USERS_NAME EMAIL USERS_GUID
```

**Example**:
```bash
./vaultlibre.sh generate_license user SomeUser someuser@example.com 12345678-1234-1234-1234-123456789012
```

(NOTE: In order to generate a **USER** license, you'll need to get a **user's GUID**. This can be retrieved most easily through the Bitwarden [Admin Portal](https://help.bitwarden.com/article/admin-portal/)).

---

#### For an Organization:
```bash
./vaultlibre.sh generate_license org ORGS_NAME EMAIL BUSINESS_NAME
```

**Example**:
```bash
./vaultlibre.sh generate_license org "My Organization Display Name" admin@mybusinesscompany.com "My Company Inc."
```

---

#### Interactive Mode (will prompt you for required input):
```bash
./vaultlibre.sh generate_license
```
# Script Options

### Syntax
```bash
./vaultlibre.sh help
```
Install using images from Docker Hub
```bash
./vaultlibre.sh install [auto] [regencerts] [recreate]
```

Install/build from Github src
```bash
./vaultlibre.sh install build  [auto] [regencerts] [recreate]
```

Update using images from Docker Hub
```bash
./vaultlibre.sh update [auto] [regencerts] [recreate] [restart]
```

Update from Github src
```bash
./vaultlibre.sh update build [auto] [regencerts] [recreate] [restart]
```

Update/force rebuild from Github src
```bash
./vaultlibre.sh update rebuild [auto] [regencerts] [recreate] [restart]
```

### Options
```yaml
AUTO                  Skip prompts, update this script, create certs only if they do not exist,
                      and recreate docker-compose.override.yml
REGENCERTS            Force regeneratioin of certificates
RECREATE              Force recreation of docker-compose.override.yml
RESTART               Force restart of Bitwarden if Bitwarden's update does not do a restart
LOCALTIME             Force Bitwarden to write logs using localtime instead of UTC 
                      (Use LOCALTIME with RECREATE, or it has no effect)
```

# Advanced

## Building VaultLibre
Alternatively, you can build the docker images yourself using the VaultLibre source code on Github.

#### Using the vaultlibre script:
```bash
curl --retry 3 "https://raw.githubusercontent.com/Ayitaka/VaultLibre/main/vaultlibre.sh" -o "./vaultlibre.sh" && chmod 0755 ./vaultlibre.sh && ./vaultlibre.sh install build
```

---

#### Manually:
Clone the VaultLibre repository to your current directory:
```bash
git clone https://github.com/Ayitaka/VaultLibre.git
```

Now that you've set up your build environment, you can **run the main build script** to generate a modified version of the `bitwarden/api` and `bitwarden/identity` docker images.

Change to the VaultLibre directory, replace the Dockerfile with the one for manually building, and run build.sh:
```bash
cd VaultLibre
mv -f .build/Dockerfile.vaultlibre ./Dockerfile
./build.sh
```

This will create a new self-signed certificate in the `.keys` directory, if one does not already exist, and then create a modified versions of the official Bitwarden images:
`bitwarden/api` -> `vaultlibre/api`
`bitwarden/identity` -> `vaultlibre/identity`

Now create the file `/path/to/bwdata/docker/docker-compose.override.yml` with the following contents to utilize the modified VaultLibre images:

```yaml
version: '3'

services:
  api:
    image: vaultlibre/api

  identity:
    image: vaultlibre/identity
```

In order to ignore errors when trying to pull the modified images (which do not exist on Docker Hub), you'll also want to edit the `/path/to/bwdata/scripts/run.sh` file. In the `function restart()` block, comment out the call to `dockerComposePull`.

> Replace `dockerComposePull`<br>with `#dockerComposePull`

You can now start or restart Bitwarden as normal and the modified api will be used. **It is now ready to accept self-issued licenses.**

## Updating Built VaultLibre and Bitwarden

#### Using the vaultlibre script:
```bash
./vaultlibre.sh update build
```

---

#### Manually:
To update Bitwarden, you can use the provided script. It will rebuild the VaultLibre images and automatically update Bitwarden afterwards. Docker pull errors can be ignored for api and identity images.

```bash
cd VaultLibre
cp -f .build/update-bitwarden.sh ./update-bitwarden.sh
```

## Manually Generating Certificate

If you wish to generate your self-signed certificate and key manually, you can run the following commands.

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.cert -days 36500 -outform DER -passout pass:test
openssl x509 -inform DER -in cert.cert -out cert.pem
openssl pkcs12 -export -out cert.pfx -inkey key.pem -in cert.pem -passin pass:test -passout pass:test
```
> Note that the password here must be `test`.<sup>[1](#f1)</sup>

Then just move the files **cert.cert cert.pem cert.pfx key.pem** to /path/to/VaultLibre/.keys

---
## Manually Generating Signed Licenses

Manually generating licenses:

There is a tool included in the directory `src/licenseGen/` that will generate new individual and organization licenses. These licenses will be accepted by the modified Bitwarden because they will be signed by the certificate you generated in earlier steps.

First, change to the`VaultLibre/src/licenseGen` directory, then replace the Dockerfile with the one for manually building, and finally **build the license generator**.<sup>[2](#f2)</sup>

```bash
cd VaultLibre/src/licenseGen
mv -f ../../.build/Dockerfile.licenseGen ./Dockerfile
./build.sh
```

In order to run the tool and generate a license you'll need to get a **user's GUID** in order to generate an **invididual license** or the server's **install ID** to generate an **Organization license**. These can be retrieved most easily through the Bitwarden [Admin Portal](https://help.bitwarden.com/article/admin-portal/).

If you generated your keys in the default `VaultLibre/.keys` directory, you can **simply run the license gen in interactive mode** from the `vaultlibre` directory and **follow the prompts to generate your license**.

```bash
./src/licenseGen/run.sh interactive
```

**The license generator will spit out a JSON-formatted license which can then be used within the Bitwarden web front-end to license your user or org!**

---

### Note: Alternative Ways to Generate License

If you wish to run the license gen from a directory aside from the root `VaultLibre` one, you'll have to provide the absolute path to your cert.pfx.

```bash
./src/licenseGen/run.sh /Absolute/Path/To/VaultLibre/.keys/cert.pfx interactive
```

Additional, instead of interactive mode, you can also pass the parameters directly to the command as follows.

```bash
./src/licenseGen/run.sh /Absolute/Path/To/VaultLibre/.keys/cert.pfx user "Name" "EMail" "User-GUID"
./src/licenseGen/run.sh /Absolute/Path/To/VaultLibre/.keys/cert.pfx org "Name" "EMail" "Install-ID used to install the server"
```
## Using a Custom Docker Override

If you want to use a custom docker-compose.override.yml you can do so by creating a file named vl.custom.override.yml and placing it in the same directory as the vaultlibre.sh script.

Following is an example with the barest minimum of requirements for the custom file's contents:

```version: '3'

services:
    api:
    image: ${DOCKERHUB}/${DOCKERHUBREPOAPI}:$BW_VERSION
    volumes:
      - ../vaultlibre/cert.cert:/newLicensing.cer

  identity:
    image: ${DOCKERHUB}/${DOCKERHUBREPOIDENTITY}:$BW_VERSION
    volumes:
      - ../vaultlibre/cert.cert:/newLicensing.cer
```

# FAQs:

# Footnotes

<a name="#f1"><sup>1</sup></a> If you wish to change this you'll need to change the value that `src/licenseGen/Program.cs` uses for its `GenerateUserLicense` and `GenerateOrgLicense` calls. Remember, this is really unnecessary as this certificate does not represent any type of security-related certificate.

<a name="#f2"><sup>2</sup></a>This tool builds on top of the `vaultlibre/api` container image so make sure you've built that above using the root `./build.sh` script.
