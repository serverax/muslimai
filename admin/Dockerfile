FROM nginx:1.27-alpine

WORKDIR /usr/share/nginx/html
COPY sakina-dashboard/admin/src/index.js ./index.js
RUN printf '%s\n' \
  '<!doctype html>' \
  '<html lang="en">' \
  '<head><meta charset="utf-8"><title>Sakina Admin</title></head>' \
  '<body><h1>Sakina Admin</h1><script type="module" src="./index.js"></script></body>' \
  '</html>' > ./index.html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
