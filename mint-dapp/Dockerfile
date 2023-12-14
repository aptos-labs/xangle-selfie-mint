ARG NODE_VERSION=21.2.0

FROM node:${NODE_VERSION}-alpine

ENV NODE_ENV production


WORKDIR /usr/src/app

ENV NODE_OPTIONS=--openssl-legacy-provider

RUN apk upgrade openssl

RUN --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=cache,target=/root/.npm \
    npm ci --omit=dev

USER node

COPY . .

EXPOSE 8000

CMD npm start
