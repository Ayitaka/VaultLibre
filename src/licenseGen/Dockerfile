FROM mcr.microsoft.com/dotnet/sdk:5.0 as build

WORKDIR /licenseGen

COPY ./src/licenseGen /licenseGen

RUN set -e; set -x; \
	dotnet add package Newtonsoft.Json --version 12.0.3 \
	&& dotnet restore \
	&& dotnet publish


FROM ayitaka/bitbetter-api:latest

COPY --from=build /licenseGen/bin/Debug/netcoreapp5.0/publish/* /app/

ENTRYPOINT [ "dotnet", "/app/licenseGen.dll", "--core", "/app/Core.dll", "--cert", "/cert.pfx" ]
