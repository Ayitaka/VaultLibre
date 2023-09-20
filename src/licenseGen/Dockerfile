FROM mcr.microsoft.com/dotnet/sdk:8.0 as build

WORKDIR /licenseGen

COPY ./src/licenseGen /licenseGen

RUN set -e; set -x; \
	dotnet add package Newtonsoft.Json --version 13.0.1 \
	&& dotnet restore \
	&& dotnet publish


FROM ayitaka/vaultlibre-api:latest

COPY --from=build /licenseGen/bin/Debug/netcoreapp6.0/publish/* /app/

ENTRYPOINT [ "dotnet", "/app/licenseGen.dll", "--core", "/app/Core.dll", "--cert", "/cert.pfx" ]
