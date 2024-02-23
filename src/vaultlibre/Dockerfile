ARG BITWARDEN_TAG

FROM mcr.microsoft.com/dotnet/sdk:8.0 as build

WORKDIR /vaultlibre

COPY ./src/vaultlibre /vaultlibre

RUN set -e; set -x; \
	dotnet add package Newtonsoft.Json --version 13.0.1 \
	&& dotnet restore \
	&& dotnet publish

FROM ${BITWARDEN_TAG}

COPY --from=build /vaultlibre/bin/Release/netcoreapp8.0/publish/* /vaultlibre/
COPY ./src/vaultlibre/vaultlibre-entrypoint.sh /
RUN chmod +x /vaultlibre-entrypoint.sh

ENTRYPOINT [ "/vaultlibre-entrypoint.sh" ]
