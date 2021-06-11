FROM node:15.5.0 as build-stage
WORKDIR /app
COPY /package*.json ./
RUN npm install
COPY ./ ./
RUN npm run build

FROM nginx:stable-alpine as production-stage
COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY ./nginx/nginx.conf /etc/nginx/nginx.conf
RUN apk --update add apache2-utils
RUN htpasswd -bc /etc/nginx/.htpasswd voicetrans mrdDeu78
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]