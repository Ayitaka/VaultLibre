<a href="https://github.com/ayitaka/BitBetter/actions"><img alt="GitHub Actions Build" src="https://github.com/ayitaka/BitBetter/workflows/BitBetter%20Image/badge.svg"></a>
<a href="https://hub.docker.com/r/ayitaka/bitbetter-api"><img alt="Docker Pulls" src="https://img.shields.io/docker/pulls/ayitaka/bitbetter-api.svg"></a>
# BitBetter

BitBetter is a tool to modify Bitwarden's core dll to allow you to generate your own individual and organisation licenses. **You must have an existing installation of Bitwarden for BitBetter to modify.**

Please see the FAQ below for details on why this software was created.

_Beware! BitBetter does janky stuff to rewrite the bitwarden core dll and allow the installation of a self signed certificate. Use at your own risk!_

Credit to:
https://github.com/jakeswenson/BitBetter for the main project
https://github.com/h44z/BitBetter for many invaluable contributions
https://github.com/alexyao2015/BitBetter for creating the starting point for adding docker images

# Table of Contents
1. [Getting Started](#getting-started)
    + [Dependencies](#dependencies)
    + [Installing BitBetter](#installing-bitbetter)
    + [Updating BitBetter and Bitwarden](#updating-bitbetter-and-bitwarden)
    + [Generating Signed Licenses](#generating-signed-licenses)
2. [Script Options](#script-options)
3. [Advanced](#advanced)
    + [Building BitBetter](#building-bitbetter)
    + [Updating Built BitBetter and Bitwarden](#updating-built--bitbetter-and-bitwarden)
    + [Manually Generating Certificate](#manually-generating-certificate)
    + [Manually Generating Signed Licenses](#manually-generating-signed-licenses)
4. [FAQ](#faq-questions-you-might-have-)
5. [Footnotes](#footnotes)

# Getting Started
The following instructions are for unix-based systems (Linux, BSD, macOS). It is possible to use a Windows based system, assuming you are able to enable and install [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10).

## Dependencies
* docker
* docker-compose
* curl
* openssl (probably already installed on most Linux or WSL systems, any version should work)
* Bitwarden (tested with 1.37.2, might work on lower versions)

## Installing BitBetter
The easiest way to install BitBetter is to use the bitbetter script which utilizes the public BitBetter docker images. These docker images are compiled automatically anytime a new version of Bitwarden is released or when changes are made to BitBetter.

#### Run the install script:

```bash
curl --retry 3 "https://raw.githubusercontent.com/Ayitaka/BitBetter/main/bitbetter.sh" -o "./bitbetter.sh" && chmod 0755 ./bitbetter.sh && ./bitbetter.sh install
```

For available options, see [Script Options](#script-options)

## Updating BitBetter and Bitwarden

#### Using the bitbetter script, you can update both BitBetter and Bitwarden:
```bash
./bitbetter.sh update auto
```

## Generating Signed Licenses
Licenses are used for enabling certain features. There are licenses for Users and for Organizations. When you install BitBetter, a script called generate_license.sh is placed in the installation directory to make generating licenses easy.

#### For a user:
```bash
./generate_license.sh user USERS_NAME EMAIL USERS_GUID
```

Example: generate_license.sh user SomeUser someuser@example.com 12345678-1234-1234-1234-123456789012

---

#### For an Organization:
```bash
./generate_license.sh org ORGS_NAME EMAIL BUSINESS_NAME
```

Example: generate_license.sh org "My Organization Display Name" admin@mybusinesscompany.com "My Company Inc."

---

#### Interactive Mode (will prompt you for required input):
```bash
./generate_license.sh
```

# Script Options

### Syntax
```bash
./bitbetter.sh help
```
Install using images from Docker Hub
```bash
./bitbetter.sh install [auto] [regencerts] [recreate]
```

Install/build from Github src
```bash
./bitbetter.sh install build  [auto] [regencerts] [recreate]
```

Update using images from Docker Hub
```bash
./bitbetter.sh update [auto] [regencerts] [recreate] [restart]
```

Update from Github src
```bash
./bitbetter.sh update build [auto] [regencerts] [recreate] [restart]
```

Update/force rebuild from Github src
```bash
./bitbetter.sh update rebuild [auto] [regencerts] [recreate] [restart]
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

## Building BitBetter
Alternatively, you can build the docker images yourself using the BitBetter source code on Github.

#### Using the bitbetter script:
```bash
curl --retry 3 "https://raw.githubusercontent.com/Ayitaka/BitBetter/main/bitbetter.sh" -o "./bitbetter.sh" && chmod 0755 ./bitbetter.sh && ./bitbetter.sh install build
```

---

#### Manually:
Clone the BitBetter repository to your current directory:
```bash
git clone https://github.com/Ayitaka/BitBetter.git
```

Now that you've set up your build environment, you can **run the main build script** to generate a modified version of the `bitwarden/api` and `bitwarden/identity` docker images.

Change to the BitBetter directory, replace the Dockerfile with the one for manually building, and run build.sh:
```bash
cd BitBetter
mv -f .build/Dockerfile.bitBetter ./Dockerfile
./build.sh
```

This will create a new self-signed certificate in the `.keys` directory, if one does not already exist, and then create a modified versions of the official Bitwarden images:
`bitwarden/api` -> `bitbetter/api`
`bitwarden/identity` -> `bitbetter/identity`

Now create the file `/path/to/bwdata/docker/docker-compose.override.yml` with the following contents to utilize the modified BitBetter images:

```yaml
version: '3'

services:
  api:
    image: bitbetter/api

  identity:
    image: bitbetter/identity
```

In order to ignore errors when trying to pull the modified images (which do not exist on Docker Hub), you'll also want to edit the `/path/to/bwdata/scripts/run.sh` file. In the `function restart()` block, comment out the call to `dockerComposePull`.

> Replace `dockerComposePull`<br>with `#dockerComposePull`

You can now start or restart Bitwarden as normal and the modified api will be used. **It is now ready to accept self-issued licenses.**

## Updating Built BitBetter and Bitwarden

#### Using the bitbetter script:
```bash
./bitbetter.sh update build
```

---

#### Manually:
To update Bitwarden, you can use the provided script. It will rebuild the BitBetter images and automatically update Bitwarden afterwards. Docker pull errors can be ignored for api and identity images.

```bash
cd BitBetter
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

Then just move the files **cert.cert cert.pem cert.pfx key.pem** to /path/to/BitBetter/.keys

---
## Manually Generating Signed Licenses

Manually generating licenses:

There is a tool included in the directory `src/licenseGen/` that will generate new individual and organization licenses. These licenses will be accepted by the modified Bitwarden because they will be signed by the certificate you generated in earlier steps.

First, change to the`BitBetter/src/licenseGen` directory, then replace the Dockerfile with the one for manually building, and finally **build the license generator**.<sup>[2](#f2)</sup>

```bash
cd BitBetter/src/licenseGen
mv -f ../../.build/Dockerfile.licenseGen ./Dockerfile
./build.sh
```

In order to run the tool and generate a license you'll need to get a **user's GUID** in order to generate an **invididual license** or the server's **install ID** to generate an **Organization license**. These can be retrieved most easily through the Bitwarden [Admin Portal](https://help.bitwarden.com/article/admin-portal/).

If you generated your keys in the default `BitBetter/.keys` directory, you can **simply run the license gen in interactive mode** from the `Bitbetter` directory and **follow the prompts to generate your license**.

```bash
./src/licenseGen/run.sh interactive
```

**The license generator will spit out a JSON-formatted license which can then be used within the Bitwarden web front-end to license your user or org!**

---

### Note: Alternative Ways to Generate License

If you wish to run the license gen from a directory aside from the root `BitBetter` one, you'll have to provide the absolute path to your cert.pfx.

```bash
./src/licenseGen/run.sh /Absolute/Path/To/BitBetter/.keys/cert.pfx interactive
```

Additional, instead of interactive mode, you can also pass the parameters directly to the command as follows.

```bash
./src/licenseGen/run.sh /Absolute/Path/To/BitBetter/.keys/cert.pfx user "Name" "EMail" "User-GUID"
./src/licenseGen/run.sh /Absolute/Path/To/BitBetter/.keys/cert.pfx org "Name" "EMail" "Install-ID used to install the server"
```

# FAQ: Questions you might have.

## Why build a license generator for open source software?

We agree that Bitwarden is great. If we didn't care about it then we wouldn't be doing this. We believe that if a user wants to host Bitwarden themselves, in their house, for their family to use amd with the ability to share access, they would still have to pay a **monthly** enterprise organization fee. When hosting and maintaining the software yourself there is no need to pay for the level of service that an enterprise customer needs.

Unfortunately, Bitwarden doesn't seem to have any method for receiving donations so we recommend making a one-time donation to your open source project of choice for each BitBetter license you generate if you can afford to do so.

## Shouldn't you have reached out to Bitwarden to ask them for alternative licensing structures?

In the past we have done so but they were not focused on the type of customer that would want a one-time license and would be happy to sacrifice customer service. We believe the features that are currently behind this subscription paywall to be critical ones and believe they should be available to users who can't afford an enterprise payment structure. We'd even be happy to see a move towards a Gitlab-like model where premium features are rolled out *first* to the enterprise subscribers before being added to the fully free version.

# Footnotes

<a name="#f1"><sup>1</sup></a> If you wish to change this you'll need to change the value that `src/licenseGen/Program.cs` uses for its `GenerateUserLicense` and `GenerateOrgLicense` calls. Remember, this is really unnecessary as this certificate does not represent any type of security-related certificate.

<a name="#f2"><sup>2</sup></a>This tool builds on top of the `bitbetter/api` container image so make sure you've built that above using the root `./build.sh` script.
