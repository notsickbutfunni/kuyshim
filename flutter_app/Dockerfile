# ── Stage 1: Build Flutter Web ────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:latest AS build

WORKDIR /app

# Copy pubspec files first for better Docker layer caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the source code
COPY . .

# Build the Flutter web app
RUN flutter build web --release --base-href "/"

# ── Stage 2: Serve with Nginx ────────────────────────────────
FROM nginx:alpine

# Remove default nginx config
RUN rm /etc/nginx/conf.d/default.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built Flutter web app to nginx html directory
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
