ARG IMAGE_VERSION=3.8-slim-buster
ARG EXTRA

FROM python:$IMAGE_VERSION
ARG EXTRA
SHELL ["/bin/bash", "-c"]
WORKDIR /dtc_de
RUN pip install --no-cache-dir -qU pip setuptools
COPY requirements.$EXTRA.txt .
RUN pip install --no-cache-dir -qr requirements.$EXTRA.txt
COPY . .
RUN if [[ -z $EXTRA ]]; then pip install -q "."; else pip install -q ".[$EXTRA]"; fi;