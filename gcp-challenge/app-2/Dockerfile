# Build stage
FROM golang:1.24.1-alpine AS builder

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /app/server

# Final stage
FROM alpine:3.21

# Add ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN adduser -D appuser

# Copy the binary from builder
COPY --from=builder /app/server /app/server

# Use non-root user
USER appuser

# Set the binary as entrypoint
WORKDIR /app
EXPOSE 8080
ENV PORT=8080

ENTRYPOINT ["/app/server"] 