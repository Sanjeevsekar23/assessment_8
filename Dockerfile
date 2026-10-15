FROM nginx:1.27-alpine

ARG APP_FAULTY=false
LABEL org.opencontainers.image.title="Northstar Student Placement Portal"
LABEL org.opencontainers.image.description="Static university placement portal"

COPY index.html /usr/share/nginx/html/index.html
RUN printf 'ready\n' > /usr/share/nginx/html/healthz \
    && if [ "$APP_FAULTY" = "true" ]; then rm /usr/share/nginx/html/healthz; fi

EXPOSE 80