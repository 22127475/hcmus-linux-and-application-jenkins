FROM nginx:alpine

RUN rm /etc/nginx/nginx.conf

RUN rm -rf /usr/share/nginx/html/*

COPY nginx/nginx.conf /etc/nginx/nginx.conf

# COPY . /usr/share/nginx/html/
COPY index.html style.css script.js /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]




