FROM node:22-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .

EXPOSE 3000

# Modo desarrollo: nodemon reinicia la API al guardar (-L = compatible con Windows/Docker)
CMD ["npx", "nodemon", "-L", "src/server.js"]
