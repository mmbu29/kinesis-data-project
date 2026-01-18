import json
import time
import random
import boto3
import os

# Read from environment variables passed by Terraform
STREAM_NAME = os.getenv("STREAM_NAME", "iot-sensor-stream")
REGION = os.getenv("REGION", "us-east-1")


def get_data():
    return {
        'sensorId': random.randint(1001, 4999),
        'currentTemperature': random.randint(20, 120),
        'alert': random.choice(["ON", "OFF"])
    }


def generate(stream_name, kinesis_client):
    while True:
        data = get_data()
        print(data)
        kinesis_client.put_record(
            StreamName=stream_name,
            Data=json.dumps(data),
            PartitionKey="partitionkey"
        )
        time.sleep(1)  # optional: slow down the loop so it doesn't spam


if __name__ == '__main__':
    generate(STREAM_NAME, boto3.client('kinesis', region_name=REGION))
