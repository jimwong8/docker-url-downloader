FROM python:3.10-slim
WORKDIR /app
COPY agent.py .
RUN pip install requests
CMD ["python", "agent.py"]