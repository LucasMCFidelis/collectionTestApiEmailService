FROM node:20-bookworm-slim

WORKDIR /etc/newman

RUN npm install -g newman newman-reporter-htmlextra

COPY postman ./postman

ENTRYPOINT ["newman"]