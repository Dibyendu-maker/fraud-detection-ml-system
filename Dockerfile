FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY pyproject.toml README.md LICENSE ./
COPY src ./src
RUN python -m pip install --upgrade pip \
    && python -m pip install .

COPY . .
RUN mkdir -p /app/models /app/data/raw \
    && useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app \
    && chmod +x scripts/docker-entrypoint.sh

USER appuser
EXPOSE 8000
ENTRYPOINT ["sh", "scripts/docker-entrypoint.sh"]
CMD ["uvicorn", "src.api.main:app", "--host", "0.0.0.0", "--port", "8000"]
