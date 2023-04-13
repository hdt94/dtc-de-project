"""
Extract trips parquet files from TCL and load them to Google Cloud Storage

This is intended to run in a virtual environment
"""

import asyncio
import datetime as dt
import os
import re

import aiofiles
import aiohttp

from google.cloud import storage


BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
WEB_URL = "https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page"


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


async def ingest_single_file(session, url, bucket, subpath):
    async with session.get(url) as res:
        data = await res.read()

    async with aiofiles.tempfile.NamedTemporaryFile("wb") as local_file:
        await local_file.write(data)

        file_basename = os.path.basename(url)
        blob = bucket.blob(f"{subpath}/{file_basename}")
        blob.upload_from_filename(local_file.name)

    return file_basename


async def ingest_files(urls, bucket_name, subpath):
    bucket = storage.Client().bucket(bucket_name)
    async with aiohttp.ClientSession() as session:
        ingestions = [
            ingest_single_file(session, url, bucket, subpath)
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

    subpath = f"raw/{vehicle_type}"
    if bucket_name:
        print("Ingesting...")
        asyncio.run(ingest_files(urls, bucket_name, subpath))

    if local_dest:
        print("Downloading...")
        asyncio.run(download_files(urls, dest=f"{local_dest}/{subpath}"))


if (__name__ == "__main__") and __debug__:
    main(
        vehicle_type="green",
        year=2023,
        bucket_name="data-dtc-dataeng-375600",
        local_dest="/home/vagrant/courses/dtc-de-project/tmp",
    )
