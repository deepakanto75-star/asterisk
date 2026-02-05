FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    netcat-openbsd curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY src/ /app

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 5000
CMD ["python", "app.py"]
