# Stage 1
FROM node:11.9.0-alpine as node-build
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install && mkdir logs
COPY ./src ./src
