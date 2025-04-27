FROM node:alpine3.18 AS builder
WORKDIR /build
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/build/node_modules npm install
COPY . .
RUN --mount=type=cache,target=/build/node_modules npm run build

FROM cgr.dev/chainguard/nginx:latest
COPY --from=builder /build/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/nginx.default.conf
EXPOSE 8080
