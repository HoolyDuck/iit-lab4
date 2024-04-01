FROM nginx:alpine 

COPY --chown=nginx . /usr/share/nginx/html

#FROM lab3_bkn

#VOLUME /usr/share/nginx/html

EXPOSE 80