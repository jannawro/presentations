import boto3
import os
import json
import logging
import random
import string
import urllib3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

cloudwatch_client = boto3.client("cloudwatch")
endpoint = "/movies"

http = urllib3.PoolManager()

headers = {'Content-Type': 'application/json'}

def lambda_handler(event, context):
    api_url = str(os.environ.get('API_URL'))
    logging.info(f"## Loaded api url from environment variable API_URL: {api_url}")

    movie_title = ''.join(random.choices(string.ascii_letters, k=12)) 
    movie_year = random.randint(1000, 9999)
    logging.info(f"## Posting movie {movie_title} made in {movie_year}")

    post_successful = 0
    r = http.request("POST", api_url+endpoint, headers=headers, body=json.dumps({
        "title": movie_title,
        "year": movie_year
    }))
    logging.info(f"## Got response: {r.status}")

    if r.status == 200:
        post_successful = 1

    post_metric("post_movie", post_successful)
    
    get_successful = 0
    r = http.request("GET", api_url+endpoint)
    items = json.loads(r.data)

    if movie_title in [item["title"]["S"] for item in items] and random.randint(1, 10) > 1:
        get_successful = 1

    post_metric("get_movie", get_successful)

def post_metric(metric_name: str, metric_value: int) -> None:
    cloudwatch_client.put_metric_data(
        MetricData=[
            {
                'MetricName': metric_name,
                'Dimensions': [
                    {
                        'Name': 'Step',
                        'Value': metric_name
                    }
                ],
                'Unit': 'None',
                'Value': metric_value
            },
        ],
        Namespace="movies"
    )
    return
