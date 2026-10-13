# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Allow git commands in safe directory
RUN git config --global --add safe.directory /app

# Copy project files
COPY . .

# Fetch dependencies
RUN flutter pub get

# Build release web app
RUN flutter build web --release --no-wasm-dry-run

# Stage 2: Serve with Nginx
FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
