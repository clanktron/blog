FROM node:alpine3.18 AS builder
COPY . /build
WORKDIR /build
RUN npm install
RUN npm run build

FROM cgr.dev/chainguard/nginx:latest
COPY --from=builder /build/dist /usr/share/nginx/html
EXPOSE 8080
