ARG BITWARDEN_TAG

FROM mcr.microsoft.com/dotnet/sdk as build

WORKDIR /vaultlibre

COPY ./src/vaultlibre /vaultlibre

RUN set -e; set -x; \
	dotnet add package Newtonsoft.Json --version 12.0.3 \
	&& dotnet restore \
	&& dotnet publish

FROM ${BITWARDEN_TAG}

COPY --from=build /vaultlibre/bin/Debug/netcoreapp5.0/publish/* /vaultlibre/
COPY ./src/vaultlibre/vaultlibre-entrypoint.sh /
RUN chmod +x /vaultlibre-entrypoint.sh

ENTRYPOINT [ "/vaultlibre-entrypoint.sh" ]
