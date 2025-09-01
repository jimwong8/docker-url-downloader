FROM mcr.microsoft.com/playwright/python:v1.48.0-jammy

RUN pip install --no-cache-dir fastapi uvicorn pydantic

WORKDIR /app
COPY resolver.py /app/resolver.py

EXPOSE 8000
CMD ["uvicorn", "resolver:app", "--host", "0.0.0.0", "--port", "8000"]