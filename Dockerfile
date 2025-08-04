FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Set work directory
WORKDIR /app

# --- Proxy and Certificate Setup ---
# Set proxy environment variables (replace with your actual proxy URLs)
ENV HTTP_PROXY=http://10.240.157.9:8080
ENV HTTPS_PROXY=http://10.240.157.9:8080
ENV NO_PROXY=localhost,127.0.0.1

# Add custom CA certificate (assumes ALL_CMT_CERT.pem is in build context)
COPY ALL_CMT_CERT.pem /usr/local/share/ca-certificates/ALL_CMT_CERT.crt
RUN update-ca-certificates

# Set CURL to use the custom CA
ENV CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

# Use proxy for apt, pip, and curl
ENV APT_HTTP_PROXY=$HTTP_PROXY
ENV APT_HTTPS_PROXY=$HTTPS_PROXY
ENV PIP_CERT=/etc/ssl/certs/ca-certificates.crt
ENV PIP_TRUSTED_HOST=10.240.157.9



# Install system dependencies using proxy and updated sources
RUN apt-get update -o Acquire::http::Proxy=$HTTP_PROXY -o Acquire::https::Proxy=$HTTPS_PROXY \
    && apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first (for better Docker layer caching)
COPY requirements.txt .

# Install Python dependencies with proxy and cert
RUN pip install --no-cache-dir --upgrade pip \
    --cert $PIP_CERT --trusted-host $PIP_TRUSTED_HOST \
    && pip install --no-cache-dir -r requirements.txt \
    --cert $PIP_CERT --trusted-host $PIP_TRUSTED_HOST

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/utils

# Expose port 8080 for websocket
EXPOSE 8080

# Health check with more reasonable timing for Cloud Run
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl --cacert /etc/ssl/certs/ca-certificates.crt -f http://localhost:8080/health || exit 1

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--log-level", "info"]
