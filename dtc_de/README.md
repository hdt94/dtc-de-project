# Core package

Core package containing modules for data engineering tasks, focused on isolation through configuration of package extras.

Execution portability is offered through container images whose building has been already setup in [root initialization script](/init-env.sh), read [root README](/README.md).

The configuration for building container images allows using:
- Cloud Build and Cloud Artifact Registry for execution on Google Cloud services:
    ```bash
    export REGISTRY_URL=
    export EXTRAS_NAMES=extract_load_trips_from_tlc_to_gs
    chmod +x ./build-docker-extras.sh
    ./build-docker-extras.sh
    ```
- local Docker runtime and registry for:
    - execution on Google Cloud services with auth based on service account attached to execution service:
        ```bash
        export EXTRAS_NAMES=extract_load_trips_from_tlc_to_gs
        chmod +x ./build-docker-extras.sh
        LOCAL=true ./build-docker-extras.sh
        ```
    - execution on any environment using GOOGLE_APPLICATION_CREDENTIALS with a service account credentials file:
        ```bash
        export GOOGLE_APPLICATION_CREDENTIALS=
        export EXTRAS_NAMES=extract_load_trips_from_tlc_to_gs
        chmod +x ./build-docker-extras.sh
        LOCAL=true ./build-docker-extras.sh
        EXTRAS_NAMES=extra_1,extra_2 ./build-docker-extras.sh
        ```

Note on "extract_load_trips_from_tlc_to_gs":
- Developing in an old system may require enforcing "urllib3<2" dependency: `pip install "urllib3<2"`; otherwise, "ImportError: urllib3 v2.0 only supports OpenSSL 1.1.1+, currently the 'ssl' module is compiled with OpenSSL 1.0.2g 1 Mar 2016"
