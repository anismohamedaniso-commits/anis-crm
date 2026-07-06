FROM ghcr.io/cirruslabs/flutter:stable AS build
ARG SUPABASE_URL
ARG SUPABASE_ANON_KEY
ARG API_BASE_URL
WORKDIR /app
COPY . .
RUN flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY --dart-define=API_BASE_URL=$API_BASE_URL
FROM node:20-alpine
RUN npm install -g serve
COPY --from=build /app/build/web /srv
CMD serve -s /srv -l tcp://0.0.0.0:$PORT
