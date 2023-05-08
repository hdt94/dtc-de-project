"""
Extract trips parquet files from TCL and load them to Google Cloud Storage

This is intended to run in a virtual environment
"""

import asyncio
import datetime as dt
import io
import os
import re

import aiofiles
import aiohttp
import pyarrow as pa
import pyarrow.parquet as pq

from google.cloud import storage


BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
WEB_URL = "https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page"

VEHICLE_TYPE_SCHEMA_MAP = {
    "green": pa.schema([
        ("VendorID", pa.string()),
        ("lpep_pickup_datetime", pa.timestamp("s")),
        ("lpep_dropoff_datetime", pa.timestamp("s")),
        ("store_and_fwd_flag", pa.string()),
        ("RatecodeID", pa.int64()),
        ("PULocationID", pa.int64()),
        ("DOLocationID", pa.int64()),
        ("passenger_count", pa.int64()),
        ("trip_distance", pa.float64()),
        ("fare_amount", pa.float64()),
        ("extra", pa.float64()),
        ("mta_tax", pa.float64()),
        ("tip_amount", pa.float64()),
        ("tolls_amount", pa.float64()),
        ("ehail_fee", pa.float64()),
        ("improvement_surcharge", pa.float64()),
        ("total_amount", pa.float64()),
        ("payment_type", pa.int64()),
        ("trip_type", pa.int64()),
        ("congestion_surcharge", pa.float64()),
    ]),
    "yellow": pa.schema([
        ("VendorID", pa.string()),
        ("tpep_pickup_datetime", pa.timestamp("s")),
        ("tpep_dropoff_datetime", pa.timestamp("s")),
        ("passenger_count", pa.int64()),
        ("trip_distance", pa.float64()),
        ("RatecodeID", pa.string()),
        ("store_and_fwd_flag", pa.string()),
        ("PULocationID", pa.int64()),
        ("DOLocationID", pa.int64()),
        ("payment_type", pa.int64()),
        ("fare_amount", pa.float64()),
        ("extra", pa.float64()),
        ("mta_tax", pa.float64()),
        ("tip_amount", pa.float64()),
        ("tolls_amount", pa.float64()),
        ("improvement_surcharge", pa.float64()),
        ("total_amount", pa.float64()),
        ("congestion_surcharge", pa.float64()),
        ("airport_fee", pa.float64()),
    ])
}


async def download_single_file(session, url, dest):
    async with session.get(url) as res:
        data = await res.read()

    file_basename = os.path.basename(url)
    async with aiofiles.open(f"{dest}/{file_basename}", "wb") as f:
        await f.write(data)

    return file_basename


async def download_files(urls, dest):
    async with aiohttp.ClientSession() as session:
        downloads = [download_single_file(session, url, dest) for url in urls]
        files = await asyncio.gather(*downloads, return_exceptions=True)

    print(f"Downloaded to {dest}: {files}")


async def ingest_single_file(session, url, bucket, subpath, schema=None):
    async with session.get(url) as res:
        data = await res.read()

    async with aiofiles.tempfile.NamedTemporaryFile("wb") as local_file:
        if schema is None:
            await local_file.write(data)
        else:
            table = pq.read_table(io.BytesIO(data)).cast(schema)
            pq.write_table(table, local_file.name)

        file_basename = os.path.basename(url)
        blob = bucket.blob(f"{subpath}/{file_basename}")
        blob.upload_from_filename(local_file.name)

    return file_basename


async def ingest_files(urls, bucket_name, subpath, schema=None):
    bucket = storage.Client().bucket(bucket_name)
    async with aiohttp.ClientSession() as session:
        ingestions = [
            ingest_single_file(session, url, bucket, subpath, schema)
            for url in urls
        ]
        uris = await asyncio.gather(*ingestions, return_exceptions=True)

    print(f"Ingested to {bucket_name}: {uris}")


async def validate_urls(urls):
    async with aiohttp.ClientSession() as session:
        async with session.get(WEB_URL) as res:
            data = await res.read()

    html = data.decode("utf-8")
    exp = re.compile(re.escape(BASE_URL) + r".*\.parquet")
    available_urls = set(exp.findall(html))

    valid_urls = []
    invalid_urls = []
    for url in urls:
        if url in available_urls:
            valid_urls.append(url)
        else:
            invalid_urls.append(url)

    return (valid_urls, invalid_urls)


def main(
    bucket_name=None,
    local_dest=None,
    vehicle_type="green",
    year=None,
    month=None,
    raise_if_any_not_found=True,
):
    """
    Ingest files to Cloud Storage bucket path "BUCKET_NAME/raw/vehicle_type/":
        # Current year and month
        main(bucket_name="BUCKET_NAME", vehicle_type="green")

        # Define year and all months
        main(bucket_name="BUCKET_NAME", vehicle_type="green", year=2022)

    Download files directly to local destination "LOCAL_DEST/raw/vehicle_type/":
        main(local_dest="LOCAL_DEST", vehicle_type="green", year=2022)
    """

    curr = dt.datetime.now()
    month_published = curr.month - 2  # data publication has two months delay

    if year is None:
        year = curr.year
        months = [month_published]
    else:
        assert type(year) is int, "year must be int"

        if month is None:
            months = range(
                1,
                13 if (year < curr.year) else month_published + 1
            )
        else:
            assert type(month) is int, "month must be int"
            months = [month]

    urls = [
        f"{BASE_URL}/{vehicle_type}_tripdata_{year}-{m:02}.parquet"
        for m in months
    ]
    (urls, invalid_urls) = asyncio.run(validate_urls(urls))
    if len(invalid_urls) > 0:
        message = f"Invalid URLs: {invalid_urls}"
        if raise_if_any_not_found:
            raise ValueError(message)
        else:
            print(message)

    if vehicle_type in VEHICLE_TYPE_SCHEMA_MAP:
        schema = VEHICLE_TYPE_SCHEMA_MAP[vehicle_type]
    else:
        schema = None

    subpath = f"raw/{vehicle_type}"
    if bucket_name:
        print("Ingesting...")
        asyncio.run(ingest_files(urls, bucket_name, subpath, schema))

    if local_dest:
        print("Downloading...")
        asyncio.run(download_files(urls, dest=f"{local_dest}/{subpath}"))


if (__name__ == "__main__") and __debug__:
    main(
        vehicle_type="green",
        year=2023,
        bucket_name="data-dtc-dataeng-375600",
        local_dest="/home/vagrant/courses/dtc-de-project/tmp",
        raise_if_any_not_found=False
    )
