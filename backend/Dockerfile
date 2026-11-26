FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt \
    && groupadd --system --gid 10001 saypal \
    && useradd --system --uid 10001 --gid saypal --no-create-home saypal

COPY backend/saypal /app/backend/saypal
COPY assets/content /app/assets/content

WORKDIR /app/backend
USER saypal
EXPOSE 8000

CMD ["python", "-m", "uvicorn", "saypal.app:app", "--host", "0.0.0.0", "--port", "8000", "--no-server-header"]
