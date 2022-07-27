#!/bin/bash

set -e
set -x

dotnet add package Newtonsoft.Json --version 13.0.1
dotnet restore
dotnet publish
