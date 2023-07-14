FROM node:alpine3.18 AS builder
COPY . /build
WORKDIR /build
RUN npm install
RUN npm run build

FROM nginx:alpine3.17
COPY --from=builder /build/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
