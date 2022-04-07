def lambda_handler(event, context):
    message = "Hello from lambda 2!"
    return {"message": message}
