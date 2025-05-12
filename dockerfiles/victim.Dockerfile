FROM nginx:latest

RUN apt update -y && apt install -y openssh-server unzip docker.io && \
    mkdir /root/docker

RUN curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.24.tgz -o docker.tgz && \
    tar xzvf docker.tgz && \
    mv docker/docker /root/docker && \
    rm -rf docker.tgz docker

RUN mkdir -p /run/sshd
RUN echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
RUN echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config
RUN echo 'root:root' | chpasswd
RUN sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' /etc/ssh/sshd_config

RUN apt install -y --no-install-recommends openssh-client

RUN ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
RUN cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys
RUN chmod 400 /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/id_rsa
RUN mkdir -p /ssh-key && cp /root/.ssh/id_rsa /ssh-key/id_rsa
RUN chmod -R 777 /ssh-key
RUN chown nobody:nogroup /ssh-key /ssh-key/id_rsa

# Cài đặt PHP và các module cần thiết
RUN apt install -y \
    php-fpm \
    php-cli \
    php-common \
    php-mysql \
    php-gd \
    php-curl \
    php-mbstring \
    php-xml \
    php-zip \


# Cấu hình Nginx để forward PHP requests đến PHP-FPM
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx/default.conf /etc/nginx/conf.d/

EXPOSE 80
EXPOSE 22

CMD ["nginx", "-g", "daemon off;"]