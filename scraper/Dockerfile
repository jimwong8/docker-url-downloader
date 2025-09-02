FROM python:3.10
WORKDIR /app
COPY app.py .
RUN pip install flask playwright
RUN playwright install
CMD ["python", "app.py"]